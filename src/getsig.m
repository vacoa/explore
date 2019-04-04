function sig = getsig(varargin)
% GETSIG Retrieve the signature for the combination of content,
% date and var (there are vertical cells)
% - matfile:    Path to .mat files (or folders containing thiese kind of files 
%               where the content is examined without the Matlab header
%               (i.e., without the first 116 bytes of the .mat file)
% - content:    Path to files or folders where the content of the file(s) is
%               examined (as well as dep content if .m file)
% - date:       Path to files or folders where the date is
%               examined (as well as dep content if .m file)
% - var:        Variable(s) is examined


p = inputParser;
addParameter(p,'matfile',{},@(x) validateattributes(x,{'cell'},{'ncols',1}));
addParameter(p,'content',{},@(x) validateattributes(x,{'cell'},{'ncols',1}));
addParameter(p,'date',{},@(x) validateattributes(x,{'cell'},{'ncols',1}));
addParameter(p,'var',{},@(x) validateattributes(x,{'cell'},{'ncols',1}));
addParameter(p,'isLinked',true,@(x) islogical(x));
parse(p,varargin{:});
mfile = p.Results.matfile;
content = p.Results.content;
savedate = p.Results.date;
var = p.Results.var;
isLinked = p.Results.isLinked;

sig = '';
for i=1:size(mfile,1)
    path = mfile{i,1};
    if exist(path,'file')==2
        sig = [sig datasig(path,'mode','matfile','isLinked',isLinked)];
    elseif exist(path,'dir')==7
        files = dir([path filesep '**/*.mat']);
        files = files(~[files.isdir],1);
        for j=1:size(files,1)
            sig = [sig datasig([files(j,1).folder filesep files(j,1).name],'mode','matfile','isLinked',isLinked)];
        end
    else
        error(['Unkown entry ' path]);
    end
end
for i=1:size(content,1)
    path = content{i,1};
    if exist(path,'file')==2
        sig = [sig datasig(path,'mode','content','isLinked',isLinked)];
    elseif exist(path,'dir')==7
        files = dir([path filesep '**/*']);
        files = files(~[files.isdir],1);
        for j=1:size(files,1)
            sig = [sig datasig([files(j,1).folder filesep files(j,1).name],'mode','content','isLinked',isLinked)];
        end
    else
        error(['Unkown entry ' path]);
    end
end
for i=1:size(savedate,1)
    path = savedate{i,1};
    if exist(path,'file')==2
        sig = [sig datasig(path,'mode','content','isLinked',isLinked)];
    elseif exist(path,'dir')==7
        files = dir([path filesep '**/*']);
        files = files(~[files.isdir],1);
        for j=1:size(files,1)
            sig = [sig datasig([files(j,1).folder filesep files(j,1).name],'mode','date','isLinked',isLinked)];
        end
    else
        error(['Unkown entry ' path]);
    end
end
for i=1:size(var,1)
    sig = [sig datasig(var,'mode','var','isLinked',isLinked)];
end

end

function [ sig, dep ] = datasig(data, varargin)
%DATASIG Get the signature of the function handle or function file full path
% specified in 'fcn'. This also can be other files without .m extension
% Return the concatenation of the functions and toolboxes saved datenum used in the
% input function or the content itself depneding on the optional parameter
% 'mode' which has to be either 'date', 'content', 'var' or 'matfile'. The 'content' option
% could be time expensive as it has to scan the content of the file and all
% the dependencies, it can be disable is 'isLinked' is set to false, by
% default it is assumed to be true

p = inputParser;
addParameter(p, 'mode', 'date', @(x) true);
addParameter(p,'isLinked',true,@(x) islogical(x));
parse(p,varargin{:});
mode = p.Results.mode;
isLinked = p.Results.isLinked;
validatestring(mode, {'date','content','var','matfile'});



if ~strcmp(mode,'var')
    % Retrieve file path
    if isa(data,'function_handle')
        tmp = functions(data);
        file = tmp.file;
    elseif isa(data,'char')
        if ~exist(data)
            error(['No file found at this path ' data]);
        else
            file = data;
        end
    else
        error('The input class should be function_handle or char');
    end
    
    % Get dependencies
    [~,~,ext] = fileparts(file);
    opt.Input = 'file';
    if strcmp(ext,'.m') && isLinked
        % Get dependency cache
        seedSessionFile = getenv('SEEDSESSION');
        isSeed = ~isempty(seedSessionFile) && exist(seedSessionFile,'file');
        exploFolder = getenv('EXPLOFOLDER');
        isExplo = ~isempty(exploFolder);
        if isSeed || isExplo
            if isSeed
                v = load(seedSessionFile);
                topInd = find(cellfun(@(x) isequal(x,true),v.env.sub.istop),1);
                depfolder = [v.env.sub.obj.folder{topInd,1} filesep 'cache' filesep 'signature'];
            elseif isExplo
                depfolder = [exploFolder filesep 'cache' filesep 'signature'];
            end
            if ~exist(depfolder,'dir')
                mkdir(depfolder);
            end
            deplabel = ['dep_' mode '_' datahash(file)];
            depmat = matfile([depfolder filesep deplabel],'Writable',true);
            if any(ismember(fieldnames(depmat),'dep'))
                updatedep = false;
                depcache = depmat.dep;
                for i=1:size(depcache,1)
                    if ~exist(depcache{i,1},'file') || ~strcmp(datahash(depcache{i,1},opt),depcache{i,2})
                        updatedep = true;
                        break;
                    end
                end
            else
                updatedep = true;
            end
            if updatedep
                dep = matlab.codetools.requiredFilesAndProducts(file)';
                for i=1:size(dep,1)
                    dep{i,2} = datahash(dep{i,1},opt);
                end
            else
                dep = depcache;
            end
            % Cache dependencies
            depmat.dep = dep;
        else
            dep = matlab.codetools.requiredFilesAndProducts(file)';
            for i=1:size(dep,1)
                dep{i,2} = datahash(dep{i,1},opt);
            end
        end
    else
        dep = {file};
        if strcmp(mode,'content')
            dep{1,2} = datahash(file,opt);
        elseif strcmp(mode,'matfile')
            opt.Input = 'matfile';
            dep{1,2} = datahash(file,opt);
        end
    end
    
    
    % Compute signature
    sig = '';
    switch mode
        case 'date'
            for i=1:size(dep,1)
                tmp = dir(dep{i,1});
                sig = [sig '<' num2str(tmp.datenum) '>'];
            end
        case {'content','matfile'}
            for i=1:size(dep,1)
                hash = dep{i,2};
                sig = [sig '<' hash '>'];
            end
    end
    
    
else
    dep = {};
    opt.Input = 'array';
    sig = ['<' datahash(data,opt) '>'];
end

end


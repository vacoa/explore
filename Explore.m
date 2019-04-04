classdef Explore < handle
    %EXPLORE Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        % Caller
        callerFile % is the session
        isInCaller
        % Paths
        workFolder
        contextFolder
        % Object
        var
        fcn
        pip
        exe
        fig
        % Util
        status
        verbose = true
        log = true
        logstr = '';
    end
    
    %% Construct (1), open session (2), init graph (3) and run (4)
    methods
        function h = Explore(varargin)
            seedSessionFile = getenv('SEEDSESSION');
            if isempty(seedSessionFile)
                conf = h.selfconfig();
                rootFolder = conf.rootFolder;
            else
                env = load(seedSessionFile);
                env = env.env;
                subind = find(cell2mat(env.sub.istop),1);
                rootFolder = env.sub.obj.folder{subind,1};
            end
            h.stdout(['Explore folder "' rootFolder '"']);
            
            % Caller
            if nargin==0
                f = dbstack('-completenames', 1);
                if size(f,1)==0 % Called from command line
                    h.callerFile = [];
                else % Called from Matlab file
                    h.callerFile = f.file;
                end
                h.isInCaller = true;
            elseif nargin==1 % Emulate the caller
                arg1 = varargin{1,1};
                if isa(arg1,'char')
                    if isempty(arg1)
                        h.callerFile = [];
                    elseif ~exist(arg1,'file')
                        error(['Caller file does not exist "' arg1 '"']);
                    elseif ~endsWith(arg1,'.m')
                        error(['Caller file is not a function or a script "' arg1 '"']);
                    else
                        h.callerFile = arg1;
                    end
                elseif isa(arg1,'function_handle')
                    f = functions(arg1);
                    if strcmp(f.type,'simple')
                        if isempty(f.file)
                            error(['Caller file does not exist for caller name "' f.function '"']);
                        else
                            h.callerFile = f.file;
                        end
                    else
                        error(['Caller function type should be "simple" but was "' f.type '"']);
                    end
                else
                    error(['First argument is not of type function handle or char "' class(arg1) '"']);
                end
                h.isInCaller = false;
            else
                error('Too many inputs');
            end
            
            % Work
            opt.Method = 'MD5';
            [~,nam,~] = fileparts(h.callerFile);
            h.contextFolder = [rootFolder filesep 'exp' filesep nam '_' datahash(h.callerFile,opt)] ;
            
            % Init
            h.var = [];
            h.fcn = [];
            h.pip = [];
            
            % Status
            h.status.graph = 'setup';
        end
        
        function h = session(h,tag)
            h.workFolder = [h.contextFolder filesep tag];
            [~, context, ~] = fileparts(h.contextFolder);
            if exist(h.workFolder,'dir')
                h.stdout(['Retrieve existing work session "' tag '" for context "' context '"']);
            else
                h.stdout(['Create new work session "' tag '" for context "' context '"']);
                mkdir(h.workFolder);
            end
        end
        
        function init(h,varargin)
            if ~exist(h.workFolder,'dir')
                error('Cannot init experiment without session, please launch "session(''<sessName>'')" method before');
            end
            h.status.graph = 'init';
            
            p = inputParser;
            addParameter(p,'plot',false,@(x) islogical(x));
            parse(p,varargin{:});
            
            h.status.plot = p.Results.plot;
            
            [~,nam,~] = fileparts(h.callerFile);
            [~,ses,~] = fileparts(h.workFolder);
            
            % Variable
            for i=1:size(h.var,1)
                folder = fileparts(h.var(i,1).sigfile);
                if ~exist(folder,'dir')
                    mkdir(folder);
                end
            end
            % Function
            for i=1:size(h.fcn,1)
                folder = fileparts(h.fcn(i,1).sigfile);
                if ~exist(folder,'dir')
                    mkdir(folder);
                end
            end
            
            % Graph
            [h.exe.graph,h.exe.edge] = h.getGraph();
            nownum = now;
            
            % Plot
            if h.status.plot
                if ishandle(h.fig)
                    close(h.fig);
                end
                
                h.fig = figure;
                pos = get(h.fig,'Position');
                pos(1,3) = pos(1,3) + 200;
                set(h.fig,'Position',pos);
                [h.exe.axg,h.exe.node] = h.plotGraph(h.exe.graph,h.exe.edge);
                title(['Session "' ses '" of context "' nam '" (' datestr(nownum) ')']);
                dcm_obj = datacursormode(h.fig);
                set(dcm_obj,'UpdateFcn',@h.tooltipCallback);
                
                % Init color
                h.setGraphColor(1:size(h.exe.node,1),rgb('DarkGray'));
                h.setLabColor(1:size(h.exe.node,1),'Black');
                
                % Legend
                hold on;
                leg = [plot(NaN,NaN,'LineStyle','-','Color',rgb('DarkGray'),'Marker','o','MarkerEdgeColor','none','MarkerFaceColor',rgb('DarkGray'),'DisplayName','Node - Not planned');...
                    plot(NaN,NaN,'LineStyle','-','Color',rgb('RoyalBlue'),'Marker','o','MarkerEdgeColor','none','MarkerFaceColor',rgb('RoyalBlue'),'DisplayName','Node - To be computed');...
                    plot(NaN,NaN,'LineStyle','-','Color',rgb('Orange'),'Marker','o','MarkerEdgeColor','none','MarkerFaceColor',rgb('Orange'),'DisplayName','Node - Being computed');...
                    plot(NaN,NaN,'LineStyle','-','Color',rgb('Green'),'Marker','o','MarkerEdgeColor','none','MarkerFaceColor',rgb('Green'),'DisplayName','Node - Has been computed');...
                    plot(NaN,NaN,'LineStyle','none','Marker','s','MarkerFaceColor','none','MarkerEdgeColor',rgb('Black'),'MarkerSize',12,'DisplayName','Fcn Box - No action');...
                    plot(NaN,NaN,'LineStyle','none','Marker','s','MarkerFaceColor','none','MarkerEdgeColor',rgb('Green'),'MarkerSize',12,'DisplayName','Fcn Box - Retrieve');...
                    plot(NaN,NaN,'LineStyle','none','Marker','s','MarkerFaceColor','none','MarkerEdgeColor',rgb('Orange'),'MarkerSize',12,'DisplayName','Fcn Box - Content diff.');...
                    plot(NaN,NaN,'LineStyle','none','Marker','s','MarkerFaceColor','none','MarkerEdgeColor',rgb('RoyalBlue'),'MarkerSize',12,'DisplayName','Fcn Box - Input diff.');...
                    plot(NaN,NaN,'LineStyle','none','Marker','s','MarkerFaceColor','none','MarkerEdgeColor',rgb('Red'),'MarkerSize',12,'DisplayName','Fcn Box - Force');...
                    plot(NaN,NaN,'LineStyle','none','Marker','o','MarkerFaceColor',rgb('DarkGray'),'MarkerEdgeColor',rgb('DarkGray'),'MarkerSize',9,'DisplayName','Marker - Branch');...
                    plot(NaN,NaN,'LineStyle','none','Marker','d','MarkerFaceColor',rgb('DarkGray'),'MarkerEdgeColor',rgb('DarkGray'),'MarkerSize',8,'DisplayName','Marker - Leaf');...
                    plot(NaN,NaN,'LineStyle','none','Marker','s','MarkerFaceColor',rgb('DarkGray'),'MarkerEdgeColor',rgb('DarkGray'),'MarkerSize',10,'DisplayName','Marker - Root');...
                    ];
                legend(leg,'Location','eastoutside');
            end
            
            % Exp trace
            folder = [h.workFolder filesep 'hist'];
            if ~exist(folder,'dir')
                mkdir(folder);
            end
            d = dir([folder filesep '*.mat']);
            num = 10; % History cache size
            if size(d,1)>=num
                tmp = [];
                for i=1:size(d,1)
                    n = d(i,1).name;
                    tmp(i,1) = datenum(n(1,1:end-4),'yyyymmddTHHMMSSFFF');
                end
                [~,n] = sort(tmp,'descend');
                for i=n(num:end,1)'
                    delete([d(i,1).folder filesep d(i,1).name]);
                end
            end
            nowstr = datestr(nownum,'yyyymmddTHHMMSSFFF');
            file = [folder filesep nowstr '.mat'];
            m = matfile(file,'Writable',true);
            m.callerName = nam;
            m.callerFile = h.callerFile;
            m.workFolder = h.workFolder;
            m.initDatestr = datestr(nownum);
            m.initDatenum = nownum;
            m.var = h.var;
            m.fcn = h.fcn;
            m.pip = h.pip;
            m.exe = h.exe;
            m.hist = [];
            setenv('EXPSTATUS',file);
        end
        
        function run(h,varargin)
            if ~strcmp(h.status.graph, 'init')
                error('Cannot run experiment without an initiated graph, please launch "init" method before');
            end
            if isempty(h.fig) || ~ishandle(h.fig)
                isplot = false;
            else
                figure(h.fig);
                isplot = true;
            end
            % Init color
            if isplot
                h.setGraphColor(1:size(h.exe.node,1),rgb('DarkGray'));
                h.setLabColor(1:size(h.exe.node,1),'Black');
            end
            
            mode.force = false;
            if isempty(varargin)
                ind = 1:size(h.fcn,1);
            else
                opt = varargin{1,1};
                ind = [];
                tok = regexp(opt,'-([\w:]+)','tokens');
                for i=1:size(tok,2)
                    opt = tok{1,i}{1,1};
                    switch opt(1,1:2)
                        case 'c:'
                            args = opt(1,3:end);
                            for i=1:size(h.fcn,1)
                                if strcmp(h.fcn(i,1).class,args)
                                    ind = [ind i];
                                end
                            end
                            if isempty(ind)
                                error(['No functions of class "' args '" found']);
                            end
                        case 'e:'
                            args = opt(1,3:end);
                            indFcn = num2str(find(ismember({h.fcn.name},args)));
                            if isempty(indFcn)
                                error(['No function name "' args '" found']);
                            end
                            par = h.parents(h.exe.graph,indFcn,{});
                            tmp = find(ismember(table2cell(h.exe.graph.Nodes),par));
                            for i=tmp'
                                if ~strcmp(h.fcn(i,1).class,'root')
                                    ind = [ind i];
                                end
                            end
                        case 's:'
                            args = opt(1,3:end);
                            ind = find(ismember({h.fcn.name},args));
                            if isempty(ind)
                                error(['No function name "' args '" found']);
                            end
                        case 'm:'
                            switch opt(1,3:end)
                                case 'f'
                                    mode.force = true;
                                otherwise
                                    error(['Mode not recognized "' opt(1,3:end) '"']);
                            end
                        otherwise
                            error(['Option not recognized "' opt(1,1:2) '"']);
                    end
                end
            end
            if isempty(ind)
                error('No function to compute');
            end
            if isempty(getenv('EXPSTATUS'))
                error('Explore is not initiated, please use "init" method');
            end
            % Trace
            nownum = now;
            t = tic;
            m = matfile(getenv('EXPSTATUS'),'Writable',true);
            hist = m.hist;
            if ~isempty(varargin)
                cmd = varargin{1,1};
            else
                cmd = '';
            end
            hist(end+1,1).cmd = cmd;
            hist(end,1).cmdind = ind;
            hist(end,1).status = 'started';
            hist(end,1).stack = [];
            hist(end,1).startDatestr = datestr(nownum);
            hist(end,1).startDatenum = nownum;
            hist(end,1).finishDatestr = '';
            hist(end,1).finishDatenum = [];
            hist(end,1).duration = [];
            hist(end,1).error = '';
            hist(end,1).log = '';
            m.hist = hist;
            function cleanup(h,t)
                nownumtmp = now;
                mtmp = matfile(getenv('EXPSTATUS'),'Writable',true);
                histtmp = mtmp.hist;
                histtmp(end,1).finishDatestr = datestr(nownumtmp);
                histtmp(end,1).finishDatenum = nownumtmp;
                histtmp(end,1).duration = toc(t);
                histtmp(end,1).status = 'finished';
                histtmp(end,1).log = h.logstr;
                mtmp.hist = histtmp;
            end
            cup = onCleanup(@() cleanup(h,t));
            % Go
            try
                h.logstr = '';
                todoclr = rgb('RoyalBlue');
                curclr = rgb('Orange');
                doneclr = rgb('Green');
                h.setGraphColor(ind,todoclr);
                drawnow;
                tmpind = [];
                for i=ind
                    tmpind = [tmpind i];
                    h.setGraphColor(tmpind,curclr);
                    if size(tmpind,2) > 1
                        h.setGraphColor(tmpind(1,1:end-1),doneclr);
                    end
                    drawnow;
                    hist(end,1).stack = [hist(end,1).stack; i];
                    m.hist = hist;
                    h.runFcn(h.fcn(i,1).name,mode.force);
                end
                h.setGraphColor(ind,doneclr);
                drawnow;
            catch e
                hist(end,1).error = getReport(e,'extended','hyperlinks','off');
                m.hist = hist;
                rethrow(e);
            end
        end
        
        function varargout = getVariable(h, varargin)
            fileInd = [];
            for i=1:nargin-1
                ind = find(ismember({h.var.name},varargin{1,i}),1);
                if isempty(ind)
                    error(['Variable "' varargin{1,i} '" does not exist.']); 
                end
                if ~exist(h.var(ind,1).file,'file')
                    error(['Variable file "' h.var(ind,1).file '" does not exist.']); 
                end
                fileInd = [fileInd ind];
            end
            for i=1:size(fileInd,2)
                ind = fileInd(1,i);
                varargout{1,i} = h.loadVar(ind);
            end
        end
        
        function setVariable(h, name, data)
            if ~strcmp(h.status.graph, 'init')
                error('Cannot set variable without an initiated graph, please launch "init" method before');
            end
            ind = find(ismember({h.var.name},name),1);
            if isempty(ind)
                error(['Cannot set variable ' name ' because it is not declared.']);
            end
            h.saveVar(ind,data);
        end
        
    end
    
    %% Building blocks
    methods
        function addPip(h,name,sigmode)
            if ~strcmp(h.status.graph, 'setup')
                error('Cannot add pipe with an initiated graph, please create the graph object again');
            end
            if ~isvarname(name) || contains(name,'_')
                error(['Cannot create pipe type, invalid name "' name '"']);
            end
            if ~isempty(h.pip) && any(ismember({h.pip.name},name))
                error(['Cannot create pipe type, name already exists "' name '"']);
            end
            p.name = name;
            switch sigmode
                case {'date','var','matfile','auto'}
                    p.sigmode = sigmode;
                otherwise
                    error(['Invalid signature mode "' sigmode '"']);
            end
            if isempty(h.pip)
                h.pip = p;
            else
                h.pip(end+1,1) = p;
            end
        end
        
        function [name,ind] = addVar(h,exename,pipname)
            if ~strcmp(h.status.graph, 'setup')
                error('Cannot add variable with an initiated graph, please create the graph object again');
            end
            name = [exename '_' pipname];
            if ~isempty(h.var) && any(ismember({h.var.name},name))
                error(['Cannot create variable, name already exists "' name '"']);
            end
            indPip = find(ismember({h.pip.name},pipname));
            if isempty(indPip)
                error(['Cannot create variable, pipe type not found "' pipname '"']);
            end
            folder = [h.workFolder filesep 'var'];
            v.name = name;
            v.exename = exename;
            v.pipname = pipname;
            v.sigmode = h.pip(indPip,1).sigmode;
            v.file = [folder filesep name '.mat'];
            v.sigfile = [folder filesep name '.sig'];
            if isempty(h.var)
                h.var = v;
            else
                h.var(end+1,1) = v;
            end
            ind = size(h.var,1);
        end
        
        function addFcn(h,name,fcn,in,out,varargin)
            if ~strcmp(h.status.graph, 'setup')
                error('Cannot add function with an initiated graph, please create the graph object again');
            end
            p = inputParser;
            addParameter(p,'class','branch',@(x) any(ismember({'root','branch','leaf'},x)));
            parse(p,varargin{:});
            validateattributes(name,{'char'},{});
            validateattributes(fcn,{'function_handle'},{});
            validateattributes(in,{'cell'},{});
            validateattributes(out,{'cell'},{});
            if size(in,1) > 1 || size(out,1) > 1
                error('Input and output variable name lists should row cell arrays or empty');
            end
            if ~isvarname(name) || contains(name,'_')
                error(['Cannot create function, invalid name "' name '"']);
            end
            if ~isempty(h.fcn) && any(ismember({h.fcn.name},name))
                error(['Cannot create function, name already exists "' name '"']);
            end
            % Argument
            inInd = [];
            inStr = {};
            for i=1:size(in,2)
                inStr{1,i} = in{1,i};
                ind = find(ismember({h.var.name},inStr{1,i}),1);
                if isempty(ind)
                    error(['Input variable ' inStr{1,i} ' is not declared']);
                else
                    inInd(1,i) = ind;
                end
            end
            outInd = [];
            outStr = {};
            for i=1:size(out,2)
                [outStr{1,i},outInd(1,i)] = h.addVar(name,out{1,i});
            end
            
            numIn = nargin(fcn);
            numOut = nargout(fcn);
            if numIn >= 0 && numIn ~= numel(in)
                error(['Expected number of input variables is ' num2str(numIn) ' but ' num2str(numel(in)) ' declared in function "' name '"']);
            end
            if numOut >= 0 && numOut ~= numel(out)
                error(['Expected number of output variables is ' num2str(numOut) ' but ' num2str(numel(out)) ' declared in function "' name '"']);
            end
            % Function
            ft = functions(fcn);
            if ~strcmp(ft.type,'simple')
                error(['Function type to memoize should be "simple" but was "' ft.type '"']);
            end
            
            % Save
            f.name = name;
            f.class = p.Results.class;
            f.handle = fcn;
            f.file = ft.file;
            f.fcnsigfile = [h.workFolder filesep 'fcn' filesep 'f_' name '.sig'];
            f.sigfile = [h.workFolder filesep 'fcn' filesep name '.sig'];
            f.outStr = outStr;
            f.outInd = outInd;
            f.inStr = inStr;
            f.inInd = inInd;
            if isempty(h.fcn)
                h.fcn = f;
            else
                h.fcn(end+1,1) = f;
            end
            
        end
        
        function varargout = info(h)
            txt = '=== I/ CONTEXT';
            [~,nam,~] = fileparts(h.contextFolder);
            txt = [txt newline 'Context name "' nam '"'];
            d = dir([h.contextFolder filesep '*']);
            for i=3:size(d,1)
               txt = [txt newline num2str(i-2) ') Session "' d(i,1).name '": '];
               tmp = dir([d(i,1).folder filesep d(i,1).name filesep 'hist' filesep '*']);
               dnum = [];
               for j=3:size(tmp,1)
                   [~,dtag,~] = fileparts(tmp(j,1).name);
                   dnum = [dnum; datenum(dtag,'yyyymmddTHHMMSSFFF')];
               end
               if ~isempty(dnum)
                   txt = [txt 'Last init = ' datestr(max(dnum))];
               else
                   txt = [txt 'Last init = <NO_INIT>'];
               end
               tmp = dir([d(i,1).folder filesep d(i,1).name filesep 'var' filesep '*.mat']);
               txt = [txt ' | Variable cache = ' num2str(size(tmp,1)) ' files - ' num2str(sum([tmp.bytes]),'%.E') ' bytes'];
            end
            if exist(h.workFolder,'dir')
                txt = [txt newline newline '=== II/ SESSION HISTORY'];
                [~,nam,~] = fileparts(h.workFolder);
                txt = [txt newline 'Session name "' nam '"'];
                folder = [h.workFolder filesep 'hist'];
                d = dir([folder filesep '*.mat']);
                hist = [];
                for i=1:size(d,1)
                    if isempty(hist)
                        hist = load([d(i,1).folder filesep d(i,1).name]);
                    else
                        hist = [hist; load([d(i,1).folder filesep d(i,1).name])];
                    end
                end
                [~,sind] = sort([hist.initDatenum]);
                hist = hist(sind,1);
                d = d(sind,1);
                for i=1:size(hist,1)
                    txt = [txt newline num2str(i) ') Init (' hist(i,1).initDatestr '): ' num2str(size(hist(i,1).fcn,1)) ' functions | ' num2str(size(hist(i,1).var,1)) ' variables | ' num2str(size(hist(i,1).pip,1)) ' pipeline classes | File = "' d(i,1).name '"'];
                    exhist = hist(i,1).hist;
                    for j=1:size(exhist,1)
                        txt = [txt newline '--- Execution (' exhist(j,1).startDatestr '): Command = "' exhist(j,1).cmd '" | Status = "' exhist(j,1).status '" | Duration = ' num2str(exhist(j,1).duration) ' seconds | Error = ' num2str(~isempty(exhist(j,1).error))];
                    end
                end
                txt = [txt newline newline '=== III/ SESSION VARIABLES'];
                folder = [h.workFolder filesep 'var'];
                %txt = [txt newline 'Variable folder "' folder '"'];
                d = dir([folder filesep '*.mat']);
                [~,sind] = sort([d.bytes],'descend');
                d = d(sind,1);
                varind = [];
                for i=1:size(d,1)
                    [~,nam,~] = fileparts(d(i,1).name);
                    txt = [txt newline num2str(i) ') Variable "' nam '": '];
                    txt = [txt 'File = "' d(i,1).name '" (' d(i,1).date ') - ' num2str(d(i,1).bytes,'%.E') ' bytes'];
                    if ~isempty(h.var)
                        ind = find(ismember({h.var.name},nam));
                    else
                        ind = [];
                    end
                    if isempty(ind)
                        txt = [txt ' | Class = <NOT_DECLARED>'];
                    else
                        varind = [varind ind];
                        txt = [txt ' | Class = ' h.var(ind,1).sigmode];
                    end
                end
                s = size(d,1);
                for i=1:size(h.var,1)
                    if ~any(varind==i)
                        s = s+1;
                        txt = [txt newline num2str(s) ') Variable "' h.var(i,1).name '": '];
                        txt = [txt ' File = <NOT_CREATED>'];
                        txt = [txt ' | Class = ' h.var(i,1).sigmode];
                    end
                end
            end
            txt = [txt newline newline '=== IV/ SESSION FUNCTIONS'];
            for j=1:size(h.fcn,1)
                f = h.fcn(j,1);
                d = dir(f.file);
                txt = [txt newline num2str(j) ') Function @' func2str(f.handle) ': '];
                txt = [txt 'Name = "' f.name '" | Class = ' f.class ' | Last change = ' d.date];
                [in,out] = h.getArgName(f.file);
                txt = [txt newline '--- Inputs = [ '];
                tmp = {''};
                for i=1:size(f.inStr,2)
                    tmp{i,1} = [in{1,1}{i,1} ' "' f.inStr{1,i} '"'];
                end
                txt = [txt strjoin(tmp,' | ') ' ]'];
                txt = [txt newline '--- Outputs = [ '];
                tmp = {''};
                for i=1:size(f.outStr,2)
                    tmp{i,1} = [out{1,1}{i,1} ' "' f.outStr{1,i} '"'];
                end
                txt = [txt strjoin(tmp,' | ') ' ]'];
                txt = [txt newline '--- Details "edit(''' f.file ''')":'];
                txt = [txt newline '    >>>' strjoin(splitlines(help(f.file)),[newline '    >>>'])];
            end
            if nargout==0
                disp(txt);
                varargout = {};
            else
                varargout{1,1} = txt;
            end
        end
    end
    
    %% Sub-functions
    
    methods (Access = private)
        
        function data = loadVar(h,ind)
            t = tic;
            h.stdout(['Action     = Load input "' h.var(ind,1).name '" (started on ' datestr(now) ')...']);
            tmp = load(h.var(ind,1).file);
            h.stdout(['             |--- Elapsed time is ' num2str(toc(t)) ' seconds.']);
            data = tmp.data;
        end
        
        function saveVar(h,ind,data)
            v = h.var(ind,1);
            t = tic;
            switch v.sigmode
                case 'date'
                    vmode = 'date';
                    vformat = '-v7.3';
                case 'matfile'
                    vmode = 'matfile';
                    vformat = '-v6';
                case 'var'
                    vmode = 'var';
                    vformat = '-v6';
                case 'auto'
                    vwhos = whos('data');
                    if vwhos.bytes > 2*10^9
                        vmode = 'date';
                        vformat = '-v7.3';
                    else
                        vmode = 'matfile';
                        vformat = '-v6';
                    end
            end
            h.stdout(['Action     = Save ' v.sigmode ' [' vmode vformat '] output "' v.name '" (started on ' datestr(now) ')...']);
            if strcmp(vformat,'-v6') && ~strcmp(v.sigmode,'date') && ~strcmp(v.sigmode,'auto')
                vwhos = whos('data');
                if vwhos.bytes > 2*10^9
                    error('Cannot save variables bigger than 2GB, please use ''date'' signature mode.');
                end
            end
            save(v.file,'data',vformat);
            h.stdout(['             |--- Elapsed time is ' num2str(toc(t)) ' seconds.']);
            t = tic;
            h.stdout(['Action     = Compute signature of output "' v.name '" (started on ' datestr(now) ')...']);
            switch vmode
                case 'matfile'
                    varsig = getsig(vmode,{v.file});
                case 'date'
                    varsig = getsig(vmode,{v.file});
                case 'var'
                    varsig = getsig(vmode,{data});
            end
            h.stdout(['             |--- Elapsed time is ' num2str(toc(t)) ' seconds.']);
            writesig(v.sigfile,varsig);
        end
        
        function runFcn(h,name,force)
            
            ind = find(ismember({h.fcn.name},name),1);
            if isempty(ind)
                error(['Function not found "' name '"']);
            end
            f = h.fcn(ind,1);
            h.stdout(['--- Function @' func2str(f.handle) ' "' f.name '" <' f.class '>']);
            tmp = splitlines(help(f.file));
            h.stdout(['Task       = ' tmp{1,1}]);
            h.stdout(['Input(s)   = [ ' strjoin(f.inStr,' | ') ' ]']);
            h.stdout(['Output(s)  = [ ' strjoin(f.outStr,' | ') ' ]']);
            t = tic;
            h.stdout(['Action     = Compute function signature (started on ' datestr(now) ')...']);
            fcnsig = getsig('content',{f.file});
            h.stdout(['             |--- Elapsed time is ' num2str(toc(t)) ' seconds.']);
            % Get signature of the execution
            % --- Function signature
            sig = fcnsig;
            % --- Output variable name signature
            sig = [sig getsig('var',{f.outStr})];
            % --- Output pipe classes signature
            pipList = unique(cellfun(@(x) x(1,strfind(x,'_')+1:end),f.outStr,'UniformOutput',false));
            pipClass = {};
            for i=1:numel(pipList)
                pind = find(ismember({h.pip.name},pipList{1,i}),1);
                if isempty(pind)
                    error(['Pipe class not declared "' pipList{1,i} '"']);
                end
                pipClass{1,i} = h.pip(pind,1).sigmode;
            end
            sig = [sig getsig('var',{pipClass})];
            % --- Input variable signature
            for i=1:size(f.inInd,2)
                varin = h.var(f.inInd(1,i),1);
                if ~exist(varin.file,'file') || ~exist(varin.sigfile,'file')
                    error(['Input not existing or not signed "' varin.name '"']);
                else
                    s = fileToCell(varin.sigfile);
                    if isempty(s)
                        error(['No signature in "' varin.sigfile '"']);
                    else
                        sig = [sig s{1,1}];
                    end
                end
            end
            % Compute or not
            if ~checksig(f.sigfile,sig) || force
                if force
                    h.stdout('Decision   = COMPUTE (forced)...');
                    writesig(f.fcnsigfile,fcnsig);
                    h.setLabColor(ind,rgb('Red'));
                elseif ~checksig(f.fcnsigfile,fcnsig)
                    h.stdout('Decision   = COMPUTE (function changed)...');
                    writesig(f.fcnsigfile,fcnsig);
                    h.setLabColor(ind,rgb('Orange'));
                else
                    h.stdout('Decision   = COMPUTE (input(s) or output(s) changed)...');
                    h.setLabColor(ind,rgb('RoyalBlue'));
                end
                varin = {};
                for i=1:size(f.inInd,2)
                    varin{1,i} = h.loadVar(f.inInd(1,i));
                end
                varout = cell(1,numel(f.outInd));
                t = tic;
                h.stdout(['Action     = Compute instructions of function (started on ' datestr(now) ')...']);
                [varout{:}] = f.handle(varin{:});
                h.stdout(['             |--- Elapsed time is ' num2str(toc(t)) ' seconds.']);
                for i=1:size(f.outInd,2)
                    data = varout{1,i};
                    h.saveVar(f.outInd(1,i),data);
                end
                writesig(f.sigfile,sig);
            else
                h.stdout('Decision   = RETRIEVE (same signatures)...');
                h.setLabColor(ind,rgb('Green'));
            end
        end
  
    end
    
    
    %% Util
    methods (Access = private)
        
        function conf = selfconfig(h)
            if ispc
                rcHome = getenv('USERPROFILE');
            else
                rcHome = getenv('HOME');
            end
            rcFile = [rcHome filesep '.explorc'];
            if ~exist(rcFile,'file')
                cellToFile(rcFile,{['rootFolder= ' rcHome filesep 'explo']});
            end
            c = fileToCell(rcFile);
            for i=1:size(c,1)
                v = strsplit(c{i,1},'=');
                if strcmp(strip(v{1,1}),'rootFolder')
                    rootFolder = strip(v{1,2});
                end
            end
            if ~exist(rootFolder,'dir')
                mkdir(rootFolder);
            end
            setenv('EXPLOFOLDER',rootFolder);
            conf.rootFolder = rootFolder;
        end
        
        function [graph,edge] = getGraph(h)
            edge = [];
            edgeLab = {};
            mat = zeros(size(h.fcn,1));
            for i=1:size(h.fcn,1)
                f = h.fcn(i,1);
                lab{1,i} = [' @' func2str(f.handle) ' "' f.name '" '];
                labInd{1,i} = num2str(i);
                for j=1:size(f.inStr,2)
                    str = strsplit(f.inStr{1,j},'_');
                    indFcn = find(ismember({h.fcn.name},str{1,1}),1);
                    if ~isempty(indFcn)
                        mat(indFcn,i) = 1;
                        tmp = [indFcn i];
                        if isempty(edge) || ~isequal(tmp,edge(end,:))
                            edge = [edge; tmp];
                            edgeLab = [edgeLab; str(1,2)];
                        else
                            edgeLab{end,1} = [edgeLab{end,1} ' | ' str{1,2}];
                        end
                    end
                end
            end
            graph = digraph(mat,labInd);
        end
        
        function [axg, node] = plotGraph(graph,edge)
            axg = plot(graph);
            axg.LineWidth = 1;
            axg.EdgeAlpha = 1;
            axg.ArrowSize = 12;
            axg.MarkerSize = 10;
            axg.EdgeColor = rgb('DarkGray');
            axg.NodeColor = rgb('DarkGray');
            xd = get(axg, 'XData')-0.05;
            yd = get(axg, 'YData')+0.22;
            node = text(xd, yd, lab, 'FontSize',10, 'FontWeight','bold', 'HorizontalAlignment','left', 'VerticalAlignment','middle','Rotation',-20,'BackgroundColor','w','EdgeColor','k','Margin',1,'LineWidth',1);
            labeledge(axg,edge(:,1)',edge(:,2)',edgeLab');
            tmp = {};
            for i=1:size(h.fcn,1)
                tmp = [tmp {''}];
            end
            axg.NodeLabel = tmp;
            for i=1:size(h.fcn,1)
                switch h.fcn(i,1).class
                    case 'root'
                        marker = 's';
                    case 'branch'
                        marker = 'o';
                    case 'leaf'
                        marker = 'd';
                    otherwise
                        error(['Unknown function class "' h.fcn.class '"']);
                end
                highlight(axg,i,'Marker',marker);
            end
            drawnow;
        end
        
        function txt = tooltipCallback(h,src,evt)
            pos = get(evt,'Position');
            ind = find(h.exe.axg.XData==pos(1,1) & h.exe.axg.YData==pos(1,2));
            f = h.fcn(ind,1);
            [in,out] = h.getArgName(f.file);
            txt = 'Inputs: [ ';
            tmp = {''};
            for i=1:size(f.inStr,2)
                tmp{i,1} = [in{1,1}{i,1} ' "' f.inStr{1,i} '"'];
            end
            txt = [txt strjoin(tmp,' | ') ' ]'];
            txt = [txt newline 'Outputs: [ '];
            tmp = {''};
            for i=1:size(f.outStr,2)
                tmp{i,1} = [out{1,1}{i,1} ' "' f.outStr{1,i} '"'];
            end
            txt = [txt strjoin(tmp,' | ') ' ]'];
        end
        
        function par = parents(h,graph,node,par)
            pred = predecessors(graph,node);
            for i=1:size(pred,1)
                if ~any(ismember(par,pred{i,1}))
                    par = [par; h.parents(graph, pred{i,1},par)];
                end
            end
            par = [par ;{node}];
        end
        
        function setGraphColor(h,ind,clr)
            if ~isempty(h.fig) && ishandle(h.fig)
                tmpedge = h.exe.edge(all(ismember(h.exe.edge,ind)'),:);
                highlight(h.exe.axg,ind,'NodeColor',clr);
                highlight(h.exe.axg,tmpedge(:,1),tmpedge(:,2),'EdgeColor',clr);
            end
        end
        
        function setLabColor(h,ind,clr)
            if ~isempty(h.fig) && ishandle(h.fig)
                for i=ind
                    h.exe.node(i,1).Color = clr;
                    h.exe.node(i,1).EdgeColor = clr;
                end
            end
        end
        
        function stdout(h,str)
            if h.log
                if ~isempty(h.logstr)
                    h.logstr = [h.logstr newline str];
                else
                    h.logstr = str;
                end
            end
            if h.verbose
                disp(str);
            end
        end
        
        function [inName,outName] = getArgName(h,fcnFile)
            % Open the file:
            fid = fopen(fcnFile);
            
            % Skip leading comments and empty lines:
            defLine = '';
            while all(isspace(defLine))
                defLine = strip_comments(fgets(fid));
            end
            
            % Collect all lines if the definition is on multiple lines:
            index = strfind(defLine, '...');
            while ~isempty(index)
                defLine = [defLine(1:index-1) strip_comments(fgets(fid))];
                index = strfind(defLine, '...');
            end
            
            % Close the file:
            fclose(fid);
            
            % Create the regular expression to match:
            matchStr = '\s*function\s+';
            if any(defLine == '=')
                matchStr = strcat(matchStr, '\[?(?<outArgs>[\w, ]*)\]?\s*=\s*');
            end
            matchStr = strcat(matchStr, '\w+\s*\(?(?<inArgs>[\w, ]*)\)?');
            
            % Parse the definition line (case insensitive):
            argStruct = regexpi(defLine, matchStr, 'names');
            
            % Format the input argument names:
            if isfield(argStruct, 'inArgs') && ~isempty(argStruct.inArgs)
                inName = strtrim(textscan(argStruct.inArgs, '%s', ...
                    'Delimiter', ','));
            else
                inName = {};
            end
            
            % Format the output argument names:
            if isfield(argStruct, 'outArgs') && ~isempty(argStruct.outArgs)
                outName = strtrim(textscan(argStruct.outArgs, '%s', ...
                    'Delimiter', ','));
            else
                outName = {};
            end
            
            % Nested functions:
            
            function str = strip_comments(str)
                if strcmp(strtrim(str), '%{')
                    strip_comment_block;
                    str = strip_comments(fgets(fid));
                else
                    str = strtok([' ' str], '%');
                end
            end
            
            function strip_comment_block
                str = strtrim(fgets(fid));
                while ~strcmp(str, '%}')
                    if strcmp(str, '%{')
                        strip_comment_block;
                    end
                    str = strtrim(fgets(fid));
                end
            end
            
            
        end
    end
    
end


% Example that provides a way to easily deal with different data while
% keeping the existing graph connections
rootFolder = [pwd filesep '..'];
warning('off');
rmpath(genpath([rootFolder filesep 'example']));
warning('on');
addpath(genpath([rootFolder filesep 'test']));

sess = 'sess1';
explo = Explore().session(sess);
switch sess
    case 'sess1'
        fcn = @fcnTestexp1;
    case 'sess2'
        fcn = @fcnTestexp1bis;
end

explo.addPip('s1','matfile');
explo.addPip('s2','date');
explo.addPip('s3','auto');

explo.addVar('v1','s3');

explo.addFcn('m1',fcn,{},{'s1','s2'},'class','branch');
explo.addFcn('m2',@fcnTestexp2,{'m1_s2','m1_s1','v1_s3'},{'s1'});
explo.addFcn('m3',@fcnTestexp3,{'m1_s1','m2_s1'},{'s3'},'class','leaf');

explo.init('plot',false);

explo.setVariable('v1_s3',3);
explo.run('-e:m3');
data = explo.getVariable('m3_s3');
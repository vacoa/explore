%% Example of a normal usage of Explore 
% All the executions are modeled as a graph where nodes are
% functions and directed edges represent data produced and consumed by the
% functions.

% For more details, please look at the file `tutorial1.html`.

%% CONFIGURATION
% Configure Matlab paths
rootFolder = [pwd filesep '..'];
warning('off');
rmpath(genpath([rootFolder filesep 'example']));
warning('on');
addpath(genpath([rootFolder filesep 'test']));

%% SESSION
% A session is used to store variables produced and consumed during
% function executions. When you change the session name, the variables are
% persisted in a different disk location. Whenever you re-use a previous
% session name, you can retrieve the data produced within the corresponding
% session.

% In this example, you can see that, depending on the
% session, different functions are used. You might want to have different 
% sessions for development and production. Here the function `@fcnTestexp1`
% might create a big data set, whereas the function `@fcnTestexp1bis` would
% create a small data set (in order to debug the code).

sess = 'sess1';
explo = Explore().session(sess);
switch sess
    case 'sess1'
        fcn = @fcnTestexp1;
    case 'sess2'
        fcn = @fcnTestexp1bis;
end

%% VARIABLES (GRAPH EDGES)
% Here, we are defining the pipes that could be used in the graph. This is
% an advanced concept, so for the moment this is not important (basically,
% this is is used to configure the way the variables are hashed).

explo.addPip('s1','matfile');
explo.addPip('s2','date');
explo.addPip('s3','auto');

% Here, we are defining a custom variable, this is also not important at
% this point of the tutorial.
explo.addVar('v1','s3');

%% FUNCTIONS (GRAPH NODES)
% When you incorporate a function (graph node) in your experiment or 
% workflow, you should add a label to the node and define its 
% inputs/outputs. For instance, when using the command
% `explo.addFcn('m2',@fcnTestexp2,{'m1_s2','m1_s1','v1_s3'},{'s1'})`
% you are defining the label 'm2' for the node executing the function 
% `@fcnTestexp2` taking 3 inputs in the following order:
%   1) The second output of the node 'm1'
%   2) The first output of the node 'm1'
%   3) The variable that is declared previously
% The node will have 1 output.

% Note that the semantics is always `<node>_<pipe>`.

% For the moment, do not pay attention to the optional argument 'class'.

explo.addFcn('m1',fcn,{},{'s1','s2'},'class','branch');
explo.addFcn('m2',@fcnTestexp2,{'m1_s2','m1_s1','v1_s3'},{'s1'});
explo.addFcn('m3',@fcnTestexp3,{'m1_s1','m2_s1'},{'s3'},'class','leaf');

%% INIT
% Here, we are initializing the graph where the checks are performed. This 
% plays the same role as a compilation step. Using the 'plot' argument, you
% can turn on/off the vizualisation of the graph execution

explo.init('plot',true);

%% EXECUTION
% The first step is to define the variables that are not produced by the
% nodes, here we are assigning the value 3 to the variable 'v1_s3'. 

explo.setVariable('v1_s3',3);

% Here, the graph and its nodes are executed to until the data produced by
% the node 'm3' is obtained. But it is also possible to execute the entire
% graph using `explo.run()`

explo.run('-e:m3');

%% DATA
% Retrieve a specific variable in the current workspace
data = explo.getVariable('m3_s3');

%% INFORMATION
% Display the following graph information in the command line:
% I/ CONTEXT: The context is associated to the script where the Explore
%   class is instanciated. Therefore, when you create an `explo` 
%   variable in another Matlab script, you will have a separated disk
%   storage.
% II/ SESSION HISTORY: You can view the status of past graph
%   executions for each session.
% III/ SESSION VARIABLES: You can display information about the variables 
%   on the disk (size, creation date, ...).
% IV/ SESSION FUNCTIONS: Information about the functions (last changes,
%   inputs, outputs, ...).
explo.info();
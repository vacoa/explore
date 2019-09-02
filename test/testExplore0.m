%% Example of a basic usage of Explore 
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
explo = Explore().session('sess1');

%% VARIABLES (GRAPH EDGES)
% Here, we are defining the pipes that could be used in the graph. This is
% an advanced concept, so for the moment this is not important (basically,
% this is is used to configure the way the variables are hashed).
explo.addPip('s1','auto');
explo.addPip('s2','auto');
explo.addPip('s3','auto');

%% FUNCTIONS (GRAPH NODES)
% This is the way to incorporate a function (graph node) in your experiment.
% A node is always defined with 4 arguments:
%   1) The label of the node. For example, 'm2'.
%   2) The function handle. For example, `@fcnTestexp2`.
%   3) The list of input argument labels. For example, 'm1_s2' refers to
%      the second output variable of the node 'm1'.
%   4) The list of output argument labels
% Basically, we are building the graph here (defining the nodes and
% connecting them). Note that the semantics of the inputs is always 
% `<node>_<pipe>`.
explo.addFcn('m1',@fcnTestexp0,{},{'s1','s2','s3'});
explo.addFcn('m2',@fcnTestexp2,{'m1_s2','m1_s1','m1_s3'},{'s1'});
explo.addFcn('m3',@fcnTestexp3,{'m1_s1','m2_s1'},{'s3'});

%% INIT
% Here, we are initializing the graph where the checks are performed. This 
% plays the same role as a compilation step. Using the 'plot' argument, you
% can turn on/off the vizualisation of the graph execution.
explo.init('plot',true);

%% EXECUTION
% Here, the nodes of the graph are executed in a topological order.
explo.run();

%% MODIFICATION AND RE-EXECUTION
% Here, we are modifying a sub-function that is called during the execution
% of the node 'm2'. Because this does not change the result of this node,
% the node 'm3' should not be re-executed.

% Add empty character at the end of the sub-function called in 'm2'.
file = which('fcnTestexp2sub');
fid = fopen(file,'a'); fprintf(fid,'%s',' '); fclose(fid); 

% Re-execution of the graph.
explo.run();

%% SUMMARY
% 1) The graph is built and executed once. Data is generated.
% 2) The code of one node is changed without any impacts on the output
%    result of this node.
% 3) The graph is re-executed and only the changed node is re-executed. All
%    other node executions are skipped since the result is expected to be
%    the same. In particular, the node 'm3' does not require 2 seconds of
%    execution anymore.

# Explore

*Explore* is a MATLAB<sup>&reg;</sup> class which implements automatic persistent memoization. You can easily declare an experiment as a *directed acyclic graph* (DAG) where the nodes are functions and the edges represent variables that are produced and consumed by functions. 

During the first execution of the graph, variables are persisted to the disk which implies a longer graph execution time (due to variable loading and saving). However, for future executions, if the node and all the sub-functions called within the node remain unchanged, the results will simply be retrieved.

For data-intensive and compute-intensive tasks, one does not necessarily have access to computer clusters or does not necessarily have resources to integrate the experiments into a separated data pipeline tool. In this case, *Explore* is the right tool to persist automatically intermediate results to the disk. Therefore, it is possible to use it as:

- a data checkpointing tool
- a data provenance tool
- [...]

*Explore* is not a substitute to workflow schedulers like Apache Airflow and moreover, it is not designed to parallelize tasks. It is a lightweight tool to avoid redundant computations.

## Quick Start

1. Download this repository.
2. Add it to the MATLAB<sup>&reg;</sup> path.
3. Run the `testExplore1` function located in the `test` folder.

## Author

Jonathan Ah Sue: <jonathan.ahsue@gmail.com>

## Thanks

This work is based on several contributions that have been slightly modified:

- Jan (2011). [DataHash](https://www.mathworks.com/matlabcentral/fileexchange/31272-datahash), MATLAB Central File Exchange.
- Ben Mitch (2002). [rgb.m](https://www.mathworks.com/matlabcentral/fileexchange/1805-rgb-m), MATLAB Central File Exchange.

Thank you !



## Work in Progress

%% Examples

% -- Run one function
%explo.run('-s:m9');

% -- Run one class
% explo.run('-c:root');

% -- Run only needed nodes to compute end node
% explo.run('-e:d4');

% -- Run only needed nodes to compute end node and force their computation
% explo.run('-e:d4-m:f');

% -- Run all processing nodes
% explo.run('-c:root');
% explo.run('-c:branch');

%% Notes
% ==== EXPERIMENT =========================================================
% You can declare the experiment using the command "explo = Explore().session('sess')"
%
% 1. You can create multiple sessions for each context. The
%   The context is the script full path where "Explore()" is called from
%   or the command line (when called from command line). 
%   All the caches and persistency will be defined and saved in the session 'sess'. 
%   If you change the name or move the main script file, it will 
%   automatically create a new context. Changing sessions will allow to
%   switch to different variable caches. This can be used for instance when
%   switching from debug (small data set) to production (bigger one).
%
% 2. You can emulate an experiment creation or retrieval from another context
%   (script or the command line) with the following commands:
%   - "explo = Explore('')" emulates the expriment from the command line
%   context
%   - "explo = Explore('~/experiments/exp1.m')" emulates the experiment
%   from the script '~/experiments/exp1.m' context
%   - "explo = Explore(@exp1)" emulates the experiment from the script
%   handle @exp1 context
%
% 3. With the command "explo.info()", you can get information on the status of 
%   variables that are declared, the history of past ".init()"
%   and ".run()" methods and also the different sessions of the context
%
% ==== GRAPH ==============================================================
% 
% 1. The method "explo.addPip('s1','var')" adds a new pipe type. Data
%   stored with this pipe are considered equal when the hash of the variable
%   content is the same. This should be used only for reasonable variable
%   sizes ( < 5-10 MB ) caching, otherwise the hashing function will take too much
%   time and you will loose the benefit of persistent memoization
%   (generally deprecated, please use 'matfile' pipe type).
%
% 2. The method "explo.addPip('s2','date')" adds a new pipe type. Data
%   stored with this pipe are considered equal when the saved time is the
%   same. This is more efficient with big data sizes ( > 1 GB).
%
% 3. The method "explo.addPip('s3','matfile')" adds a new pipe type. Data
%   stored with this pipe are considered equal when the content of a .mat
%   file without its header is the same. This is more efficient with standard data sizes.
%   ( 5MB < size < 1GB )
%
% 4. The method "explo.addFcn('m4',@pow1,{'m2_s1','m3_s1'},{'s1'})" adds a
%   new computational node (like Python's decorator) called 'm4' to the function @pow1, mapping
%   the pipe 's1' from the decorator 'm2' to the first input of @pow1 and
%   the pipe 's1' from the decorator 'm3' to the second input of @pow1
%
% 5. By default the node class is 'branch' but you can change it to 'leaf'
%   or 'root', using for example, 
%       "explo.addFcn('m1',@data1,{},{'s1','s2'},'class','root')".
%   
%   - A 'root' node will not be executed automatically. This is very useful
%   when working with both small and big data sets. Usually, you use a
%   small data set to validate your scripts and debug them, so you do not
%   want to import the data every time but only on demand executing the
%   specific class of nodes 'root'. To switch to a bigger data set, you can
%   processed the 'root' nodes again by changing paths to point to the
%   bigger data set.
%   - Typically, a 'leaf' node should be a display node, i.e., no big
%   computations should happen.
%   - Therefore, executing the 'branch' nodes will trigger all the big
%   computations without displaying their result (in 'leaf' nodes) and 
%   without building the data set again (in 'root' nodes)
%
% 6. Because the semantic includes underscores to declare a variable 
%   (output pipe from a node, e.g., 'm2_s1'), the only restriction is that
%   the pipe and node names should not contain any underscores.
%
% 7. To run the computation graph, use "explo.run()". This will run by default 
%   all the branch and leaf nodes. You can options to the method in order 
%   to compute only chosen nodes:
%   - Class run: "explo.run('-c:root')" will compute only all the 'root' nodes
%   - Solo run: "explo.run('-s:m1')" will compute or retrieve only node 'm1'
%   - End run: "explo.run('-e:m1')" will compute or retrieve only the nodes 
%   needed to obtain the output of node 'm1'
%   - Run with another mode: "explo.run('-s:m1-m:f')" will force to compute 
%   the node 'm1' even if the result could be retrieved, i.e., even if the 
%   inputs and the function content and dependencies did not have changed
%
% ==== FIGURE =============================================================
% After you init the graph with "explo.init()", you can view different types 
% of information to let you know about the status of the computational graph.
%
% 1. After ".run()" - Status of computations:
%   A node or edge is gray when the computation is not planned
%   A node or edge is blue when it is planned but not computed yet
%   A node or edge is orange when it is being computed at the current time
%   A node or edge is green when the computation is finished
%
% 2. After ".run()" - Status of functions (after computation or retrieval):
%   A function label is green when the result is retrieved
%   A function label is orange when the function content has changed and
%   maybe also the inputs
%   A function label is blue hwne the function content is the same but
%   inputs have changed
%   A function label is red when it was forced
%
% 3. On the figure - Information on function arguments
%   You can view information on the function arguments by clicking on the
%   nodes with the tooltip.
%
% 4. On the figure - Shape of the nodes
%   A circle node represents a 'branch' node.
%   A diamond node represents a 'leaf' node.
%   A square node represents a 'root' node.
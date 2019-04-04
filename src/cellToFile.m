function cellToFile(file,cellStr)
%CELLTOFILE Summary of this function goes here
%   Detailed explanation goes here

validateattributes(cellStr,{'cell'},{'ncols',1}); 
for i=1:size(cellStr,1)
   if ~ischar(cellStr{i,1})
      error(['At line ' num2str(i) ' of cell, the variable is not a string']); 
   end
end

% [folder,tag,ext] = fileparts(file); %% NEED TO WRITE TO CONFIG FILES
% validatestring(ext,{'.txt','.log','.sig'});


% if exist(file,'file') %% TAKE TOO MUCH TIME FOR SIGNATURES
%     if ~isempty(folder)
%         copyfile(file,[folder filesep tag '_backup' ext]);
%     else
%         copyfile(file,[tag '_backup' ext]);
%     end
% end

fid = fopen(file,'W');
if fid==-1
    error(['File cannot be opened ' file]);
end
try
    fprintf(fid,'%s\n',cellStr{:});
catch e
    fclose(fid);
    rethrow(e);
end
fclose(fid);

end


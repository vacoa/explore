function cellStr = fileToCell(file)
%FILETOCELL Get the content of the file in a vertical cell of strings

str = fileread(file);
cellStr = splitlines(str);
if numel(cellStr)==1 && isempty(cellStr{1,1})
    cellStr = {};
else
    if isempty(cellStr{end,1})
        cellStr = cellStr(1:end-1,1);
    end
end

end


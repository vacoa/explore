function writesig( sigfile, sig )
%WRITESIG Write 'sig' into 'sigfile'

if ~exist(sigfile)
    fclose(fopen(sigfile,'w+'));
end
cellToFile(sigfile,{sig});

end


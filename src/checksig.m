function bool = checksig(sigfile,sig)
%CHECKSIG Return a boolean indicating whether the signature in the
%'sigfile' is equal to the signature 'sig' which is a string typically
%returned by 'getsig.m' function

if ~exist(sigfile)
    bool = false;
else
    oldSig = fileToCell(sigfile);
    if isempty(oldSig)
        bool = false;
    else
        oldSig = oldSig{1,1};
        bool = strcmp(sig,oldSig);
    end
end

end


function explo = nbsession(sessName)
% Function to be use in Jupyter notebook, otherwise fileparts fails
explo = Explore().session(sessName);
end
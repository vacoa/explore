function [c] = fcnTestexp2(a,b,d)
% Second test function
i = fcnTestexp2sub(3);
disp(i);
c = a*b+d;
pause(2);
end

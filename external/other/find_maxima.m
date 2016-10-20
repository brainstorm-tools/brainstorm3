function [maxima_values,maxima_indices] = find_maxima(signal)

% if complex, use modulus
if ~isreal(signal)
    signal=abs(signal);
end

% row vector
if size(signal,1)>size(signal,2)
    signal=signal';
end

% get first global max
[temp,tempinds]=max(signal);
maxima_indices=tempinds(1);

% maxima in middle
d=diff(abs(signal));
maxima_indices=[maxima_indices ...
    1+find((d(1:end-1)>0)&(d(1:end-1).*d(2:end))<0)];

% maxima at first point
if abs(signal(1))>abs(signal(2))
    maxima_indices=[1 maxima_indices];
end
% maxima at last point
if abs(signal(end))>abs(signal(end-1))
    maxima_indices=[maxima_indices length(signal)];
end
maxima_indices=unique(maxima_indices);
maxima_values=signal(maxima_indices);


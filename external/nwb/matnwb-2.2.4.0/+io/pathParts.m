function [stem, root] = pathParts(path)
stem = '';
sepindices = strfind(path, '/');
 
if isempty(sepindices)
   root = path;
   return;
end
lastsepidx = sepindices(end);
stem = path(1:lastsepidx-1);
root = path(lastsepidx+1:end);
end
function [condlabel,condidval,conditiongen,data2,condlabel2,condidval2] = sll_checkdatacondid(data,condid,varargin)

%preliminary code, undocumented; please do not distribute
% Author: Dimitrios Pantazis 


kfold = sll_inputparser(varargin,'kfold',5, @(x) isscalar(x) && x>=2 && x == round(x));


%check data vs. condid
if ~isnumeric(data) | ndims(data)~=3
    error('''data'' is invalid');
end
if ~iscell(condid)
    error('''condid'' is not a cell');    
end
if length(condid) ~= size(data,3)
    error('The number of observations (trials) is different in ''data'' and ''condid''.');
end

%convert condition labels to numbers
condlabel = unique(condid,'stable'); %unique condition labels in given order
numcond = length(condlabel); %number of conditions
condidval = zeros(size(condid),'single');
for i = 1:length(condid) %convert condition strings to numbers
    condidval(i) = find(strcmp(condlabel,condid(i)));
end
mincond = min(histcounts(condidval,numcond)); %smallest condition repetitions

%default
conditiongen = false;
data2 = [];
condlabel2 = [];
condidval2 = [];

%if data2 provided
if nargin>=1 & isnumeric(varargin{1}) %if data2 provided for cross-condition generalization
    
    if nargin == 1
        error('Wrong number of inputs');
    end
    
    data2 = varargin{1}; %numeric argument is data2
    condid2 = varargin{2}; %next argument is condid2
    conditiongen = true;
    
    %check data2 vs. condid2
    if ~isnumeric(data2) | ndims(data2)~=3
        error('''data2'' is invalid');
    end
    if ~iscell(condid2)
        error('''condid2'' is not a cell');
    end
    if length(condid2) ~= size(data2,3)
        error('The number of observations (trials) is different in ''data2'' and ''condid2''.');
    end

    %check data vs data2
    if size(data,1) ~= size(data2,1) | size(data,2) ~= size(data2,2)
        error('''data'' and ''data2'' have different number of variables or time points.');
    end
   
    %convert condition labels to numbers
    condlabel2 = unique(condid2,'stable'); %unique condition labels in given order
    numcond2 = length(condlabel2); %number of conditions
    
    if numcond~=numcond2
        error('Number of conditions do not agree between ''condid'' and ''condid2''');
    end
    
    condidval2 = zeros(size(condid2),'single');
    for i = 1:length(condid2) %convert condition strings to numbers
        condidval2(i) = find(strcmp(condlabel2,condid2(i)));
    end
    
    %minimum condition repetitions
    mincond2 = min(histcounts(condidval2,numcond2)); %smallest condition repetitions

    mincond = min([mincond mincond2]);
end

%if kfold greater than the minimum number of trials in a condition
if kfold>mincond 
    error(['kfold should be less or equal to the minimum number of observations (trials) in a condition (' num2str(mincond) ')']);
end
    
    




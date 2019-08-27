function dist = sll_distanceeuclcv(data,condid,varargin)

%preliminary code, undocumented; please do not distribute
%data is 3D (variables, timepoints,observations)
%condid is a cell of strings denoting the condition id for each observation
%
%temporalgen output: dsvm.d: (test time x train time x conditions)
%multiclass output: dsvm.d: (actual condition x predicted condition x conditions)
%
% example: 
%  d = sll_distanceeuclcv(data,condid,'numpermutation',10,'verbose',2); 
%
% Author: Dimitrios Pantazis 


%% parse inputs

numpermutation  = sll_inputparser(varargin,'numpermutation',100, @(x) isscalar(x) && x>0 && x == round(x) );
kfold           = sll_inputparser(varargin,'kfold',5, @(x) isscalar(x) && x>=2 && x == round(x));
method          = sll_inputparser(varargin,'method','pairwise',{'pairwise','temporalgen'}); 
whiten          = sll_inputparser(varargin,'whiten',true);
verbose         = sll_inputparser(varargin,'verbose',false);


%% check inputs and convert string labels to numbers

[condlabel,condidval,conditiongen,data2,condlabel2,condidval2] = sll_checkdatacondid(data,condid,varargin{:});


%% initialize variables

numcond = length(condlabel); %number of conditions
rng('shuffle'); %seed the random number generator based on the current time
d = 0; %store decoding results
d2 = 0; %store decoding results (if cross-condition generalized)


%% compute cross-validated Euclidean distance
for p = 1:numpermutation
    
    %% verbose permutation
    
    if verbose & ~rem(p,verbose)
        disp(['Permutation: ' num2str(p) ' out of ' num2str(numpermutation)]);
    end
    
    
    %% assign data to k folds
    
    foldid = sll_createfolds(condidval,kfold);
    for c = 1:numcond
        traindata{c} = mean(data(:,:,condidval==c & foldid<kfold),3);
        testdata{c} = mean(data(:,:,condidval==c & foldid==kfold),3);
        if conditiongen
            n = nnz(condidval==c & foldid==kfold); %we need that many elements from data2
            cndx = find(condidval2==c); %available elements in condition c
            testdata2{c} = mean(data2(:,:,cndx(randperm(length(cndx),n))),3);
        end
    end
    
    
    %% multivariate noise normalization (whiten data)
    
    if whiten        
        %compute whitening matrix using only training data
        down = max(round(size(data,2)/100),1); %downsample the data to make computation fast
        W = sll_whitenmatrix(data(:,1:down:end,foldid<kfold),condidval(foldid<kfold));        
        %apply whitening matrix
        for c = 1:numcond
            traindata{c} = W*traindata{c}; %multiply data with whitener 
            testdata{c} = W*testdata{c}; %multiply data with whitener 
            if conditiongen
                testdata2{c} = W*testdata2{c};
            end
        end
    end
    

    %% Euclidean cross-validated distance
    
    d = d + distanceeuclcv(traindata,testdata,method);
    if conditiongen
        d2 = d2 + distanceeuclcv(traindata,testdata2,method);
    end

    
end


%% normalize output

d = d/numpermutation; %divide by number of permutations
d2 = d2/numpermutation; %divide by number of permutations


%% parse output

dist.d                 = d;
dist.condlabel         = condlabel;
dist.numpermutation    = numpermutation;
dist.kfold             = kfold;
dist.whiten            = whiten;
dist.method            = method;
if conditiongen
    dist.d2            = d2;
    dist.condlabel2    = condlabel2;
end


%% local function; computes Euclidean cross-validated distance
function d = distanceeuclcv(traindata,testdata,method)  

%initial variables
ncond = length(traindata);
ntimes = size(traindata{1},2);
[x,y] = find(tril(ones(ncond,ncond),-1)); %indices of lower triangle

switch method

    case 'pairwise'
        
        %pairwise Euclidean cross-validated distance
        d = zeros(ntimes,ncond*(ncond-1)/2,'single');
        for i = 1:length(x)
            d(:,i) = sum( (traindata{x(i)}-traindata{y(i)}).*(testdata{x(i)}-testdata{y(i)}))'; %cross-validated Euclidean distance
        end
        
    case 'temporalgen'
        
        %pairwise Euclidean cross-valideated with temporal generalization     
        d = zeros(ntimes,ntimes,ncond*(ncond-1)/2,'single');
        for i = 1:length(x)
            d(:,:,i) = (traindata{x(i)}-traindata{y(i)})' * (testdata{x(i)}-testdata{y(i)}); %cross-validated Euclidean distance
        end
        
end





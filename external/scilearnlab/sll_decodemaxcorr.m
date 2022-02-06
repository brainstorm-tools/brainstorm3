function dec = sll_decodemaxcorr(data,condid,varargin)

%preliminary code, undocumented; please do not distribute
%data is 3D (variables, timepoints,observations)
%condid is a cell of strings denoting the condition id for each observation
%
%temporalgen output: dsvm.d: (test time x train time x conditions)
%multiclass output: dsvm.d: (actual condition x predicted condition x conditions)
%
% example: 
%  d = sll_decodemaxcorr(data,condid,'numpermutation',10,'verbose',2); 
%
% Author: Dimitrios Pantazis 


%% parse inputs

numpermutation  = sll_inputparser(varargin,'numpermutation',100, @(x) isscalar(x) && x>0 && x == round(x) );
kfold           = sll_inputparser(varargin,'kfold',5, @(x) isscalar(x) && x>=2 && x == round(x));
method          = sll_inputparser(varargin,'method','pairwise',{'pairwise','temporalgen','multiclass'}); 
whiten          = sll_inputparser(varargin,'whiten',true);
verbose         = sll_inputparser(varargin,'verbose',false);


%% check inputs and convert string labels to numbers

[condlabel,condidval,conditiongen,data2,condlabel2,condidval2] = sll_checkdatacondid(data,condid,varargin{:});


%% initialize variables

ncond = length(condlabel); %number of conditions
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
    for c = 1:ncond
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
        for c = 1:ncond
            traindata{c} = W*traindata{c}; %multiply data with whitener 
            testdata{c} = W*testdata{c}; %multiply data with whitener 
            if conditiongen
                testdata2{c} = W*testdata2{c};
            end
        end
    end
    
   
    %% decode using max correlation
    d = d + decodemaxcorr(traindata,testdata,method);
    if conditiongen
        d2 = d2 + decodemaxcorr(traindata,testdata2,method);
    end
        
end


%% normalize output

scale = 100/numpermutation/2;
if strcmp(method,'multiclass')
    scale = scale*2;
end
d = d*scale;
if conditiongen
    d2 = d2*scale;
end


%% parse output

dec.d                       = d;
dec.condlabel               = condlabel;
dec.numpermutation          = numpermutation;
dec.kfold                   = kfold;
dec.whiten                  = whiten;
dec.method                  = method;
if conditiongen
    dec.d2                  = d2;
    dec.condlabel2          = condlabel2;
end


%% local function; computes decoding with maxcorr
function d = decodemaxcorr(traindata,testdata,method)  

%initial variables
ncond = length(traindata);
ntimes = size(traindata{1},2);

% remove mean and divide by standard deviation (to speedup computation of Pearson corr)
for c = 1:ncond
    traindata{c} = bsxfun(@minus,traindata{c},mean(traindata{c},1));  % Remove mean
    sx = sqrt(sum(abs(traindata{c}).^2, 1)); % sqrt first to avoid under/overflow; (1/(n-1) doesn't matter, renormalizing anyway)
    traindata{c} = bsxfun(@rdivide,traindata{c},sx);
    testdata{c} = bsxfun(@minus,testdata{c},mean(testdata{c},1));  % Remove mean
    sx = sqrt(sum(abs(testdata{c}).^2, 1)); % sqrt first to avoid under/overflow
    testdata{c} = bsxfun(@rdivide,testdata{c},sx);
end

switch method
    
    case 'pairwise'
        %pairwise decoding
        d = zeros(ntimes,ncond*(ncond-1)/2,'single');
        ndxmat = squareform(1:ncond*(ncond-1)/2); %index used to map 2D to squareform
        for i = 1:ncond
            coefii = sum(traindata{i} .* testdata{i}); %compute correlation coefficient
            for j = [1:i-1 i+1:ncond] %for all j ~= i
                coefij = sum(traindata{i} .* testdata{j});
                correct = coefii - coefij > 0; %difference of correlation coef
                d(:,ndxmat(i,j)) = d(:,ndxmat(i,j)) + correct';
            end
        end
        
    case 'temporalgen'
        
        %pairwise decode with temporal generalization
        d = zeros(ntimes,ntimes,ncond*(ncond-1)/2,'single');
        ndxmat = squareform(1:ncond*(ncond-1)/2); %index used to map 2D to squareform
        for i = 1:ncond
            coefii = traindata{i}' * testdata{i}; %compute correlation coefficient
            for j = [1:i-1 i+1:ncond] %for all j ~= i
                coefij = traindata{i}' * testdata{j};
                correct = coefii - coefij > 0; %difference of correlation coef
                d(:,:,ndxmat(i,j)) = d(:,:,ndxmat(i,j)) + single(correct)';
            end
        end
        
    case 'multiclass'
        
        %pairwise decoding
        %compute correlation coefficient
        coef = zeros(ntimes,ncond,ncond,'single'); %coef is time x train x test
        for i = 1:ncond
            for j = 1:ncond
                coef(:,i,j) = sum(traindata{i} .* testdata{j});
            end
        end
        
        %assign 1 to maximum correlation category
        d = zeros(ntimes,ncond,ncond,'single');
        [x,I] = max(coef,[],2); %operate on train dimension
        for t = 1:ntimes
            for c = 1:ncond
                d(t,I(t,1,c),c) = d(t,I(t,1,c),c) + 1;
            end
        end
        
end



    
    
    
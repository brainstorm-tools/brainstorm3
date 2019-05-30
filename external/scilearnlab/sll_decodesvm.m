function dec = sll_decodesvm(data,condid,varargin)

%preliminary code, undocumented; please do not distribute
%data is 3D (variables, timepoints,observations)
%condid is a cell of strings denoting the condition id for each observation
%
%temporalgen output: dsvm.d: (test time x train time x conditions)
%multiclass output: dsvm.d: (actual condition x predicted condition x conditions)
%
% example: 
%  d = sll_decodesvm(data,condid,'numpermutation',10,'verbose',2); 
%
% Author: Dimitrios Pantazis 


%% parse inputs

[~]             = sll_inputparser(varargin,[],0, {'numpermutation' 'kfold' 'method' 'whiten' 'dvweighted' 'verbose'} ); %check is all parameters valid
numpermutation  = sll_inputparser(varargin,'numpermutation',100, @(x) isscalar(x) && x>0 && x == round(x) );
kfold           = sll_inputparser(varargin,'kfold',5, @(x) isscalar(x) && x>=2 && x == round(x));
method          = sll_inputparser(varargin,'method','pairwise',{'pairwise','temporalgen','multiclass'}); 
whiten          = sll_inputparser(varargin,'whiten',true);
dvweighted      = sll_inputparser(varargin,'dvweighted',false);
verbose         = sll_inputparser(varargin,'verbose',false);


%% check inputs and convert string labels to numbers

[condlabel,condidval,conditiongen,data2,condlabel2,condidval2] = sll_checkdatacondid(data,condid,varargin{:});


%% check if libsvm software exists and preceeds in path

try 
    warning off
    svmtrain([0 1],[0 1],'-s 0 -t 0 -q'); %this should not produce errors in libsvm is installed
    warning on
catch
    disp(['This function uses the LIBSVM software. It calls the svmtrain function',char(10),...
        'which has the same name as the Matlab''s builtin function. To use, adjust the',char(10),...
        'Matlab path so that SIBSVM''s svmtrain precedes the one from Matlab']);
    dec = [];
    return;
end


%% initialize variables

[nvar,ntimes,~] = size(data);
numcond = length(condlabel); %number of conditions
rng('shuffle'); %seed the random number generator based on the current time
d = 0; %store decoding results
d2 = 0; %store decoding results (if cross-condition generalized)
ncond = max(condidval);
traindata = zeros(nvar,ntimes,numcond*(kfold-1),'single');
testdata = zeros(nvar,ntimes,ncond,'single');
trainlabel = double(reshape(ones(kfold-1,1)*(1:ncond),[],1));
testlabel = double((1:ncond))';


%% compute svm

for p = 1:numpermutation

    %% verbose output
    
    if verbose & ~rem(p,verbose)
        disp(['Permutation: ' num2str(p) ' out of ' num2str(numpermutation)]);
    end

    
    %% assign data to k folds
    foldid = sll_createfolds(condidval,kfold);
    for c = 1:ncond
        for k = 1:kfold-1
            traindata(:,:,(c-1)*(kfold-1)+k) = mean(data(:,:,condidval==c & foldid==k),3);
        end
        testdata(:,:,c) = mean(data(:,:,condidval==c & foldid==kfold),3);
        if conditiongen
            n = nnz(condidval==c & foldid==kfold); %we need that many elements from data2
            cndx = find(condidval2==c); %available elements in condition c
            testdata2(:,:,c) = mean(data2(:,:,cndx),3);
        end
    end
    
    
    %% multivariate noise normalization (whiten data)
    
    if whiten
        %compute whitening matrix using only training data
        down = max(round(size(data,2)/100),1); %downsample the data to make computation fast
        W = sll_whitenmatrix(data(:,1:down:end,foldid<kfold),condidval(foldid<kfold));
        %apply whitening matrix
        traindata = reshape(W*reshape(traindata,nvar,[]),nvar,ntimes,[]); %whiten data; trick to multiply 3D matrix
        testdata = reshape(W*reshape(testdata,nvar,[]),nvar,ntimes,[]); %whiten data; trick to multiply 3D matrix
        if conditiongen
            testdata2 = reshape(W*reshape(testdata2,nvar,[]),nvar,ntimes,[]); %whiten data; trick to multiply 3D matrix
        end            
    end
   
    d = d + decodesvn(traindata,testdata,trainlabel,testlabel,dvweighted,method);
    if conditiongen
        d2 = d2 + decodesvn(traindata,testdata2,trainlabel,testlabel,dvweighted,method);
    end
    
end


%% normalize output

scale = 100/numpermutation/2;
if strcmp(method,'multiclass')
    scale = scale*2;
    d = permute(d,[3,1,2]);
end
d = d*scale;
if conditiongen
    d2 = d2*scale;
    if strcmp(method,'multiclass')
        d2 = permute(d2,[3,1,2]);
    end
end


%% parse output

dec.d                       = d;
dec.condlabel               = condlabel;
dec.numpermutation          = numpermutation;
dec.kfold                   = kfold;
dec.whiten                  = whiten;
dec.method                  = method;
dec.dvweighted              = dvweighted;
if conditiongen
    dec.d2                  = d2;
    dec.condlabel2          = condlabel2;
end


 
%% local function; computes decoding with svm
function d = decodesvn(traindata,testdata,trainlabel,testlabel,dvweighted,method)  

ncond = max(testlabel);
ntimes = size(traindata,2);

switch method 
    
    case 'pairwise'
        
        %hack: recover pairwise comparisons using a typical svmtrain multiclass call
        dv_elements = zeros(ncond,ncond*(ncond-1)/2,'single');
        for c = ncond-1:-1:1
            rows = ncond-c:ncond;
            cols = sum(c+1:ncond-1)+1:sum(c+1:ncond-1)+c;
            dv_elements(rows,cols) = [ones(1,c);-eye(c)];
        end
        dv_plus_ndx = find(dv_elements>0);
        dv_minus_ndx = find(dv_elements<0);
        
        d = zeros(ncond*(ncond-1)/2,ntimes,'single'); %used because it saves memory in parfor
        parfor t = 1:ntimes
            model = svmtrain(trainlabel,double(squeeze(traindata(:,t,:))'),'-s 0 -t 0 -q -b 0');
            [~, ~, decision_values] = svmpredict(testlabel, double(squeeze(testdata(:,t,:))'), model,'-q');
            if ~dvweighted
                d(:,t) = single(decision_values(dv_plus_ndx)>0) + single(decision_values(dv_minus_ndx)<0); %decoding accuracy
            else
                d(:,t) = single(decision_values(dv_plus_ndx)) - single(decision_values(dv_minus_ndx)); %decision value weighted classification
            end
        end
        d = d';
        
        
    case 'temporalgen'
        
        %hack: recover pairwise comparisons using a typical svmtrain multiclass call
        dv_elements = zeros(ncond,ncond*(ncond-1)/2,'single');
        for c = ncond-1:-1:1
            rows = ncond-c:ncond;
            cols = sum(c+1:ncond-1)+1:sum(c+1:ncond-1)+c;
            dv_elements(rows,cols) = [ones(1,c);-eye(c)];
        end
        for c = 1:ncond
            dv_plus_ndx{c} = find(dv_elements(c,:)>0);
            dv_minus_ndx{c} = find(dv_elements(c,:)<0);
        end
        
        %implemented in blocks to save memory
        slicesize = 100; %hard coded slice size
        [tndx,ssize,nslices] = sll_sliceblocks(ntimes,slicesize);
        d = zeros(ntimes,ntimes,ncond*(ncond-1)/2,'single'); %decoding values
        for s = 1:nslices
            traindata_slice = traindata(:,tndx{s},:);
            ds = zeros(ntimes,ssize(s),ncond*(ncond-1)/2,'single');
            parfor t = 1:ssize(s)
                model = svmtrain(trainlabel,double(squeeze(traindata_slice(:,t,:))'),'-s 0 -t 0 -q');
                dv_plus = zeros(ntimes,ncond*(ncond-1)/2,'single');
                dv_minus = zeros(ntimes,ncond*(ncond-1)/2,'single');
                for c = 1:ncond
                    [~, ~, decision_values] = svmpredict(c*ones(ntimes,1), double(testdata(:,:,c)'), model,'-q');
                    dv_plus(:,dv_plus_ndx{c}) = decision_values(:,dv_plus_ndx{c});
                    dv_minus(:,dv_minus_ndx{c}) = decision_values(:,dv_minus_ndx{c});
                end
                if ~dvweighted
                    ds(:,t,:) = permute(single(dv_plus>0) + single(dv_minus<0),[1 3 2]); %time dimesion needs to be last (otherwise very slow)
                else
                    ds(:,t,:) = permute(single(dv_plus) - single(dv_minus),[1 3 2]); %time dimesion needs to be last (otherwise very slow)
                end
            end
            d(:,tndx{s},:) = ds;
        end
        
    case 'multiclass'
        
        d = zeros(ncond,ncond,ntimes,'single'); %used because it saves memory in parfor
        parfor t = 1:ntimes
            model = svmtrain(trainlabel,double(squeeze(traindata(:,t,:))'),'-s 0 -t 0 -q -b 0');
            predicted_label = svmpredict(testlabel, double(squeeze(testdata(:,t,:))'), model,'-q');
            ndx = sub2ind([ncond,ncond],predicted_label,testlabel);
            a = zeros(ncond,ncond);
            a(ndx) = 1;
            d(:,:,t) = a;
        end
                
        
end
function [foldid,nobs] = sll_createfolds(condid,kfold)

%preliminary code, undocumented; please do not distribute
% Author: Dimitrios Pantazis 


ncond = max(condid);
nobs = histcounts(condid,ncond);

%% assign folds
testfold = floor(min(nobs)/kfold); %equal observations for all conditions in test fold
for c = 1:ncond
    foldsize(1:kfold-1) = floor((nobs(c)-testfold)/(kfold-1)); %assign equal data to kfold-1 training folds
    foldsize(kfold) = testfold; %assign testfold data to test fold
    k = nobs(c)-sum(foldsize); %find extra elements
    foldsize(1:k) = foldsize(1:k)+1;   %assign extra elements to training folds
    for k = 1:kfold
        id{k} = k*ones(1,foldsize(k)); %create folder id elements
    end
    foldid_cond{c} = [id{:}]; %concatenate foldid elements
    foldid_cond{c} = foldid_cond{c}(randperm(nobs(c))); %randomize order
end

%assign to proper conditions (if trials are not ordered by condition)
for c = 1:ncond
    foldid(find(condid == c)) = foldid_cond{c};
end


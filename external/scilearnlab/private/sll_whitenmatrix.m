function W = fl_whitenmatrix(data,condid)

%preliminary code, undocumented; please do not distribute
% Author: Dimitrios Pantazis 


%% initialize variables

[nvar,ntimes,~] = size(data);
ncond = max(condid);
Cov = zeros(nvar,nvar);


%% compute whitening matrix

for c = 1:ncond
    dat = data(:,:,condid==c ); %select condition data
    for t = 1:ntimes
        %important: compute noise covariance within conditions (not across conditions) and just for training set
        [sigma,shrinkage]=cov1para(squeeze(dat(:,t,:))'); %compute invertible covariance matrix
        Cov = Cov + sigma; %sum over times and conditions
    end
end
Cov = Cov/(ncond*ntimes);
W = Cov^-0.5; %whitening matrix



    
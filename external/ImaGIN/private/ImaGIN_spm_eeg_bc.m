function d = ImaGIN_spm_eeg_bc(D, d)
% 'baseline correction' for D: subtract average baseline energy of the 
% samples (start:stop) per epoch.
% FORMAT d = spm_eeg_bc(D, d)
%
%_______________________________________________________________________
% Copyright (C) 2005 Wellcome Department of Imaging Neuroscience

% Stefan Kiebel
% $Id: spm_eeg_bc.m 133 2005-05-09 17:29:37Z guillaume $

index=[];
for i1 = 1:size(D.tf.Sbaseline,1)
    index=[index [D.tf.Sbaseline(i1,1):D.tf.Sbaseline(i1,2)]];
end
for i = 1 : length(D.tf.channels)
    for j = 1 : D.Nfrequencies
        tmp1 = mean(d(i, j, index), 3);
        tmp2 = squeeze(std(d(i, j, index), [],3));
        tmp2(find(tmp2==0))=1;
        d(i, j, :) = squeeze(d(i, j, :) - tmp1)./(ones(size(d,3),1)*tmp2);
    end
end

%
% [f, v] = ezf_checkMaltabVersion()
% 
% Description:
%     Check Matlab version for EZF
% 
% Input:
% 
% Output:
%     f - 1: no issue; 0: not fully functional; -1: too old
%     v - version number in brainstorm format
% 
% Copyright:
%     2019 (c) USC Biomedical Imaging Group (BigLab)
% Author:
%     Jian Li (Andrew)
% Revision:
%     1.0.0
% Date:
%     2019/01/29
%

function [f, v] = ezf_checkMaltabVersion()

    v = bst_get('MatlabVersion');
    
    if v < 800 % before R2012b
        f = -1;
    elseif (v >= 800) && (v < 901) % between R2012b and R2016b
        f = 0;
    else
        f = 1;
    end
    
end
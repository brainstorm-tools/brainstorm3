%
% [isInstalled, ezfAppInfo] = ezf_checkEZFInstallation()
% 
% Description:
%     Check whether EZF is installed
% 
% Input:
% 
% Output:
%     isInstalled - binary flag
%     ezfAppInfo - EZF app info
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

function [isInstalled, ezfAppInfo] = ezf_checkEZFInstallation()
    
    isInstalled = false;
    ezfAppInfo = struct();
    
    f = ezf_checkMaltabVersion();
    if f >= 0 % when app util exists
        allAppInfo = matlab.apputil.getInstalledAppInfo;

        if ~isempty(allAppInfo)
            for m = 1:length(allAppInfo)
                appName = allAppInfo(m).name;

                if strcmp(appName, 'EZFingerprint')
                    isInstalled = true;
                    ezfAppInfo = allAppInfo(m);
                end
            end
        end
    end
    
end
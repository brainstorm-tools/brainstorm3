%
% d = ezf_getProcessDescription()
% 
% Description:
%     Get descriptions for brainstorm process based on MATLAB version and EZF installation status
% 
% Input:
% 
% Output:
%     d - description string
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

function d = ezf_getProcessDescription()
    
    try
        f = ezf_checkMaltabVersion();
        [isEZFInstalled, tmp] = ezf_checkEZFInstallation();

        d = '';
        if f == -1
            d = [d, ...
                'You have a MATLAB version earlier than R2012b<br>', ...
                'Hence the Epileptogenic Zone Fingerprint (EZF) can not be installed/opened.<br><br>', ...
                'Click ''Run'' to the EZF webpage to check the system requirements<br><br>'];
        elseif f >= 0
            if isEZFInstalled
                d = [d, ...
                    'You have the Epileptogenic Zone Fingerprint (EZF) installed already.<br>'];
                if f == 0
                    d = [d, ...
                        'However your MATLAB version is older than the recommended R2016b, ', ...
                        'the EZF may not be fully functional.<br><br>'];
                elseif f == 1
                    d = [d, '<br>'];
                end
                d = [d, 'Click ''Run'' to start the EZF<br><br>'];
            else
                d = [...
                    'The Epileptogenic Zone Fingerprint (EZF) is not installed.<br><br>', ...
                    'Click ''Run'' to the EZF webpage to download and install.<br><br>'];
            end
        end
    catch
        d = ['If your MATLAB version is earlier than R2012b<br>', ...
            'the Epileptogenic Zone Fingerprint (EZF) can not be installed/opened.<br>', ...
            'Click ''Run'' to the EZF webpage to check the system requirements<br><br>', ...
            'If your MATLAB version is later than R2012b but earlier than R2016b<br>', ...
            'note that the EZF may not be fully functional.<br><br>', ...
            'If the EZF is not installed, click ''Run'' to the EZF webpage to download and install.<br><br>', ...
            'Otherwise, click ''Run'' to start the EZF software<br><br>'];
    end
    
    d = [d, 'For more information about EZF, see:<br>', ...
            'https://silencer1127.github.io/software/EZ_Fingerprint/ezf_main<br><br>'];
    
end

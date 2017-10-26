function userDir = getuserdir
% GETUSERDIR  Retrieve the user directory
%   - Under Windows returns the %APPDATA% directory
%   - For other OSs uses java to retrieve the user.home directory

if ispc
    %     userDir = winqueryreg('HKEY_CURRENT_USER',...
    %         ['Software\Microsoft\Windows\CurrentVersion\' ...
    %          'Explorer\Shell Folders'],'Personal');
    userDir = getenv('appdata');
else
    userDir = char(java.lang.System.getProperty('user.home'));
end
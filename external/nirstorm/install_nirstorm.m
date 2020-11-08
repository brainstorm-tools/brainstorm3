function [status,err] = install_nirstorm(extra,mode, tmp_folder)
% Download and install NISTORM in Brainstorm
% Input : 
% Extra: option to install extra feature from nirstorm (debug, wip)
%  - debug for developping tool, wip for work in progress feature
% mode: mode of installation; either copy or link. Copy recommended for non
% develloper. 
% tmp_folder, download location. Usefull only for developper using the link
% option. 

err= {};
status = 1;
nistorm_url = 'https://github.com/Nirstorm/nirstorm/archive/master.zip';

if nargin < 1
   extra={}; 
end
if nargin < 2
   mode='copy'; 
end
if nargin < 3
   tmp_folder = bst_get('BrainstormTmpDir');
end

nistorm_folder=fullfile(tmp_folder,'nirstorm-master');
try 
    unzip(nistorm_url,tmp_folder);
catch
   err='Unable to download nirstorm';
   status = 0; 
   return;
end

addpath(nistorm_folder);

try 
    nst_install(mode,extra,nistorm_folder )
catch ME
    err = ME.message;
    status = 0;
    return;
end    

if strcmp(mode,'copy')
    rmpath(nistorm_folder)
    rmpath( fullfile(nistorm_folder, 'dist_tools'));
    
    [status,msg] = rmdir(nistorm_folder, 's');
    err= msg;
end
end


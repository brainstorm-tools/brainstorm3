function [status,err] = install_nirstorm(extra,mode, tmp_folder)
% INSTALL_NIRSTORM Download and install NIRSTORM in Brainstorm
% 
% INPUTS: 
%    - extra: cell array, list of extra features to install from nirstorm ('debug', 'wip')
%       - 'debug': install developping tool
%       - 'wip': install work in progress features
%    - mode: String, installation mode:
%       - 'copy': recommended for non-developpers
%       - 'link': 
%    - tmp_folder: Download location. Useful only for developper using the link option
%
% Authors: Edouard Delaire, 2020

err = {};
status = 1;
nistorm_url = 'https://github.com/Nirstorm/nirstorm/archive/master.zip';

if (nargin < 1) || isempty(extra)
   extra = {}; 
end
if (nargin < 2) || isempty(mode)
   mode = 'copy'; 
end
if (nargin < 3) || isempty(tmp_folder)
   tmp_folder = bst_get('BrainstormTmpDir');
end

nirstorm_folder = fullfile(tmp_folder,'nirstorm-master');
try 
    unzip(nistorm_url,tmp_folder);
catch
   err = 'Unable to download nirstorm';
   status = 0; 
   return;
end

addpath(nistorm_folder);

try 
    nst_install(mode,extra,nistorm_folder);
catch ME
    err = ME.message;
    status = 0;
    return;
end    

if strcmp(mode,'copy')
    rmpath(nistorm_folder)
    rmpath(fullfile(nistorm_folder, 'dist_tools'));
    
    [status,msg] = rmdir(nistorm_folder, 's');
    err = msg;
end
end


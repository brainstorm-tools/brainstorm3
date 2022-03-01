function errMsg = bst_websave(filename, url)
% BST_WEBSAVE: Save the content of a URL to a file

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c) University of Southern California & McGill University
% This software is distributed under the terms of the GNU General Public License
% as published by the Free Software Foundation. Further details on the GPLv3
% license can be found at http://www.gnu.org/copyleft/gpl.html.
% 
% FOR RESEARCH PURPOSES ONLY. THE SOFTWARE IS PROVIDED "AS IS," AND THE
% UNIVERSITY OF SOUTHERN CALIFORNIA AND ITS COLLABORATORS DO NOT MAKE ANY
% WARRANTY, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF
% MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, NOR DO THEY ASSUME ANY
% LIABILITY OR RESPONSIBILITY FOR THE USE OF THIS SOFTWARE.
%
% For more information type "brainstorm license" at command prompt.
% =============================================================================@
%
% Authors: Francois Tadel, 2022

errMsg = '';

% FTP download with Matlab >= 2021b
if (bst_get('MatlabVersion') >= 911) && ~isempty(strfind(url, 'ftp://'))
    try
        % Split URL in host/path
        urlSplit = str_split(url, '/');
        urlHost = urlSplit{2};
        if (length(urlSplit) >= 3)
            urlPath = sprintf('%s/', urlSplit{3:end-1});
        else
            urlPath = [];
        end
        urlFile = urlSplit{end};
        % Get destination path
        [destPath, destFile, destExt] = bst_fileparts(filename);
        destFile = [destFile, destExt];
        % Create an FTP object and downloads the file
        ftpobj = ftp(urlHost);
        cd(ftpobj, urlPath);
        mget(ftpobj, urlFile, destPath);
        close(ftpobj);
        % Rename downloaded file
        movefile(bst_fullfile(destPath, urlFile), bst_fullfile(destPath, destFile), 'f');
        return;
    catch
        disp('BST> ERROR: FTP download failed.');
    end
end

% Reading function: urlread replaced with webread in Matlab 2014b
if (bst_get('MatlabVersion') <= 803)
    url_read_fcn = @(f,u)urlwrite(u,f);
    url_read_alt = @(f,u)websave(f,u);
else
    url_read_fcn = @(f,u)websave(f,u);
    url_read_alt = @(f,u)urlwrite(u,f);
end
% Read online version.txt
try
    url_read_fcn(filename, url);
catch
    err = lasterror;
    try
        url_read_alt(filename, url);
    catch
        errMsg = ['websave and urlwrite failed reading URL: ' url 10 str_striptag(err.message)];
        disp(['BST> ERROR: ' errMsg]);
    end
end

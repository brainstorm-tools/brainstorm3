function [isOk, onlineRel] = bst_check_internet()
% BST_CHECK_INTERNET:  Check if an internet connection is available.

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2017 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2009-2012

urlChar = 'http://neuroimage.usc.edu/bst/getversion.php';
onlineRel = [];
try
    % Open the URL for reading
    handler = sun.net.www.protocol.http.Handler;
    url = java.net.URL([],urlChar,handler);
    % Open HTTP connection
    urlConnection = url.openConnection();
    urlConnection.setConnectTimeout(5000);
    urlConnection.setReadTimeout(5000);
    urlConnection.connect();
    % Read online version.txt file
    inputStream = urlConnection.getContent();
    % Get release date
    onlineRel = readVersion(inputStream);
    % Close stream
    inputStream.close();
    % Return success
    isOk = 1;
catch
    isOk = 0;
end

end


%% ===== READ VERSION.TXT =====
function onlineRel = readVersion(inputStream)
    % Read file
    version_txt = '';
    stop = 0;
    while ~stop
        val = inputStream.read();
        if (val > 0)
            version_txt(end+1) = char(val);
        else
            stop = 1;
        end
    end
    if (length(version_txt) < 20)
        warning('Cannot read online version.txt');
        VER = [];
        return;
    end
    % Find release date in text file
    iParent = strfind(version_txt, '(');
    dateStr = version_txt(iParent - 7:iParent - 2);
    % Interpetation of date string
    onlineRel.year  = str2num(dateStr(1:2));
    onlineRel.month = str2num(dateStr(3:4));
    onlineRel.day   = str2num(dateStr(5:6));
end



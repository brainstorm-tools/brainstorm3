function java_setcb(jObj, varargin)
%JAVA_SETCB: Associate Matlab callbacks to a Java object.
% 
% USAGE:  java_setcb(jObj, CallbackName1, CallbackFunction1, CallbackName2, CallbackFunction2, ...)

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
% Authors: Francois Tadel, 2010

% Old syntax, before Matlab2010b
% for i = 1:2:length(varargin)
%     set(jObj, varargin{i}, varargin{i+1});
% end

% New syntax: Matlab 2010b
hObj = handle(jObj, 'callbackProperties');
for i = 1:2:length(varargin)
    set(hObj, varargin{i}, varargin{i+1});
end




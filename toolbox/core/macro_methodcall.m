% MACRO_METHODCALL: Script to insert at the beginning of all the brainstorm class functions
% 
% DEPRECATED:  Use "eval(macro_method);" instead.

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2020 University of Southern California & McGill University
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
% Authors: Francois Tadel, The Mathworks, 2010-2016


% Get current stack trace
dbStack = dbstack();
% Get the call just one level above
if (length(dbStack) > 1)
    strScript = sprintf('%s.m at line %d', dbStack(2).name, dbStack(2).line);
else
    strScript = 'Unknown';
end
    
% Display warning when this function is called
disp([10 '*******************************************************************************' ...
      10 '*** WARNING: In function: ' strScript ...
      10 '***          The process API changed, due to modifications in Matlab 2016b.' ...
      10 '***          Replace "macro_methodcall;" with "eval(macro_method);"' ...
      10 '***          at the beginning of all your Brainstorm functions.' ...
      10 '*******************************************************************************']);
  
  
  
% Matlab versions: 2006b-2016a
if bst_verlessthan(901)
    % No parameters: nothing to do
    if (nargin == 0)
    % Else : execute appropriate local function
    elseif ischar(varargin{1})
        if (nargout)
            [varargout{1:nargout}] = feval(str2func(varargin{1}), varargin{2:end});
        else
            feval(str2func(varargin{1}), varargin{2:end});
        end
    end

% Matlab versions: >= 2016b
% FiS Incompatibility fix (developed by The Mathworks, 2016)
else
    % Catch stupid warnings after 2016b (macro_methodcall.m not working anymore)
    warning('off', 'MATLAB:lang:GetCallerInfoWarning');
    % Builtin to capture the caller info, the structure contains nargin, nargout and local function handles in the caller.
    callerinfo = builtin('_GetCallerInfo');
    fcnNames = cellfun(@func2str,callerinfo.localFunctions,'UniformOutput',false);

    if(length(varargin) >= 1)
        ind1 = strcmp(fcnNames, varargin{1});
    end
    % FiS Incompatibility fix
    if (callerinfo.nargin == 0)
    % Else : execute appropriate local function
    elseif ischar(varargin{1})
        % FiS Incompatibility fix
        if (callerinfo.nargout)
            % FiS Incompatibility fix
            [varargout{1:callerinfo.nargout}] = feval(callerinfo.localFunctions{ind1}, varargin{2:end});
        else
            % FiS Incompatibility fix
            feval(callerinfo.localFunctions{ind1}, varargin{2:end});
        end
    end
end


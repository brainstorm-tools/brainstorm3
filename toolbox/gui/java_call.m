function res = java_call(obj, objMethod, methodProto, varargin)
% JAVA_CALL: Call a method on a Java object on the EDT.

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
% Authors: Francois Tadel, 2013

% Parse inputs
if (nargin < 3)
    methodProto = [];
    nParam = 0;
else
    nParam = length(varargin);
end
% Initialize output
res = [];
% Call the creation with the latest available function
if exist('javaMethodEDT', 'builtin')
    if (nParam == 0)
        if (nargout == 1)
            res = javaMethodEDT(objMethod, obj);
        else
            javaMethodEDT(objMethod, obj);
        end
    else
        if (nargout == 1)
            res = javaMethodEDT(objMethod, obj, varargin{:});
        else
            javaMethodEDT(objMethod, obj, varargin{:});
        end
    end
else
    if (nParam == 0)
        if (nargout == 1)
            res = awtinvoke(obj, objMethod);
        else
            awtinvoke(obj, objMethod);
        end
    else
        if (nargout == 1)
            res = awtinvoke(obj, [objMethod, '(', methodProto, ')'], varargin{:});
        else
            awtinvoke(obj, [objMethod, '(', methodProto, ')'], varargin{:});
        end
    end
end





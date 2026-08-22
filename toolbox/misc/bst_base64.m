function y = bst_base64(action, x)
% BST_BASE64: Encode or decode Base64 data, independently from the Java version.
%
% USAGE:  bytes = bst_base64('decode', str)    % str  : char array (line breaks allowed)
%                                              % bytes: int8 vector
%           str = bst_base64('encode', bytes)  % bytes: int8/uint8 vector (or Java byte[])
%                                              % str  : char array (no line breaks)
%
% DESCRIPTION:
%     The classes sun.misc.BASE64Decoder and sun.misc.BASE64Encoder used previously were
%     internal JDK classes, removed in Java 9. Recent versions of Matlab ship with a newer
%     JDK, in which they are not available anymore ("Unable to find or import
%     'sun.misc.BASE64Decoder'"). This function uses java.util.Base64 instead (Java >= 8),
%     with fallbacks for older environments.

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
% Authors: Bhushan Thombre, 2026

switch lower(action)
    % ===== DECODE =====
    case 'decode'
        % Convert to a simple char row, remove all the white spaces and line breaks
        x = char(x);
        x = x(:)';
        x(x <= 32) = [];
        if isempty(x)
            y = zeros(0, 1, 'int8');
            return;
        end
        try
            % Java >= 8
            y = java.util.Base64.getMimeDecoder().decode(java.lang.String(x));
        catch
            try
                % Matlab >= R2016b, no Java needed
                y = typecast(matlab.net.base64decode(x), 'int8');
            catch
                % Java <= 8
                decoder = sun.misc.BASE64Decoder();
                y = decoder.decodeBuffer(x);
            end
        end
        y = y(:);
        
    % ===== ENCODE =====
    case 'encode'
        x = typecast(x(:), 'int8');
        try
            % Java >= 8
            y = char(java.util.Base64.getEncoder().encodeToString(x));
        catch
            try
                % Matlab >= R2016b, no Java needed
                y = char(matlab.net.base64encode(typecast(x, 'uint8')));
            catch
                % Java <= 8
                encoder = sun.misc.BASE64Encoder();
                y = char(encoder.encode(x));
            end
        end
        % Remove the line breaks possibly added by the encoder
        y = y(:)';
        y((y == 10) | (y == 13)) = [];
        
    otherwise
        error(['Unsupported action: ' action]);
end

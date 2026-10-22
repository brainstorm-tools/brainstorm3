function y = bst_base64(action, x)
% BST_BASE64: Encode or decode Base64 data, independently from the Java version.
%
% USAGE:  y = bst_base64('encode', x)      % x : char vector,   y : int8 column vector
%         y = bst_base64('decode', x)      % x : int8 vector,   y : char row vector
%
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
%          Raymundo Cassani, 2026

y = [];

% Note: Using `eval` allows using `import` inside an IF statement,
%       otherwise it runs before the statement. See `import` help
[tEncoder, dEncoder] = methodsview('sun.misc.BASE64Encoder', 'noui');
[tDecoder, dDecoder] = methodsview('sun.misc.BASE64Decoder', 'noui');

% API JDK > 8
if isempty(tEncoder) || isempty(dEncoder) || isempty(tDecoder) || isempty(dDecoder)
    % sun.misc.BASE64Decoder and sun.misc.BASE64Encoder have been removed in JDK 9;
    % instead, use java.util.Base64
    % https://docs.oracle.com/javase/9/migrate/toc.htm#JSMIG-GUID-B96BD00F-12A4-493A-9907-2FFE8DA6748C
    eval('import java.util.Base64.getDecoder');
    eval('import java.util.Base64.getEncoder');
    encoder = getEncoder();
    decoder = getDecoder();
    encode  = @encoder.encode;       % Returns int8 with a trailing '\n'
    decode  = @decoder.decode;       % Returns int8
% API JDK = 8
else
    eval('import sun.misc.BASE64Decoder');
    eval('import sun.misc.BASE64Encoder');
    decoder = BASE64Decoder();
    encoder = BASE64Encoder();
    encode  = @encoder.encodeBuffer; % Returns Java string
    decode  = @decoder.decodeBuffer; % Returns int8
end

switch lower(action)
    case 'encode'
        % To char array without trailing '\n'
        y = strtrim(char(encode(x)));
        y = y(:)';
    case 'decode'
        y = decode(x);
    otherwise
        error(['Unsupported action: ' action]);
end

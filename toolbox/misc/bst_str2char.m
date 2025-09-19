function varOut = bst_str2char(varIn)
% BST_STR2CHAR: Convert any string array in varIn to char vector in varOut
%               Work recursively for elements in cells and fields in structs
%               Classes different of string array are not modified
% 
% INPUTS:
%    - varIn:  String array, or cell or struct with string arrays to convert
%    - varOut: Same class as varIn, but string arrays are not char vectors
%
% EXAMPLE: 
%    varIn.cell  = {"Hello", "Brainstorm"};
%    varIn.str   = "Brainstorm";
%    varIn.strs  = ["Hello", "Brainstorm"];
%
%    varOut = bst_str2char(varIn)
%
%  varOut = 
%
%    struct with fields:
%
%      cell: {'Hello'  'Brainstorm'}
%       str: 'Brainstorm'
%      strs: {'Hello'  'Brainstorm'}
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
% Author: Raymundo Cassani, 2025

classIn = class(varIn);
switch classIn
    case 'string'
        if numel(varIn) == 1
            varOut = char(varIn);
        else
            varOut = cellstr(varIn);
        end

    case 'cell'
        varOut = cellfun(@bst_str2char, varIn, 'UniformOutput', false);

    case 'struct'
        varOut = varIn;
        fields = fieldnames(varIn);
        for ix = 1:numel(varIn)            
            for jx = 1:numel(fields)
                varOut(ix).(fields{jx}) = bst_str2char(varIn(ix).(fields{jx}));
            end
        end        

    otherwise
        varOut = varIn;
end

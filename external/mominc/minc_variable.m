function val = minc_variable(hdr,var_name,att_name)
% Read a MINC variable inside a header
% VAL = MINC_VARIABLE( HDR , [VAR_NAME] , [ATT_NAME] )
%
% HDR (structure) a minc header read with MINC_READ
% VAR_NAME (string, optional) the name of a variable. 
% ATT_NAME (string, optional) the name of an attribute.
% VAL (various types) 
%   if VAR_NAME and ATT_NAME are both specified, VAL is the value of the 
%      specified variable/attribute. 
%   If only VAR_NAME is specified, VAL is the list of attributes of the 
%      variable (cell of strings). 
%   If VAR_NAME is unspecified, VAL is the list of variables (cell of strings). 
%   
% Example:
% [hdr,vol] = minc_read('my_vol.mnc');
% dcosinesy = minc_variable(hdr,'yspace','direction_cosines');
%
% Maintainer : pierre.bellec@criugm.qc.ca
% See licensing information in the code. 

% Copyright (c) Pierre Bellec, Centre de recherche de l'institut de
% gériatrie de Montréal, Département d'informatique et de recherche
% opérationnelle, Université de Montréal, 2013-2014.
% Keywords : medical imaging, I/O, reader, minc
%
% Permission is hereby granted, free of charge, to any person obtaining a copy
% of this software and associated documentation files (the "Software"), to deal
% in the Software without restriction, including without limitation the rights
% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
% copies of the Software, and to permit persons to whom the Software is
% furnished to do so, subject to the following conditions:
%
% The above copyright notice and this permission notice shall be included in
% all copies or substantial portions of the Software.
%
% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
% THE SOFTWARE.

if (nargin<1)||~isstruct(hdr)||~isfield(hdr,'details')||~isfield(hdr.details,'variables')||~isfield(hdr.details,'globals')
    error('Please specify a valid HDR structure, see MINC_READ')
end

hdr = hdr.details;

list_var = {hdr.variables(:).name}; 

if nargin == 1
    val = list_var;
    return
end

if nargin >= 2
    ind = find(ismember(list_var,var_name));
    if isempty(ind)
        error('Could not find variable %s in HDR',var_name)
    end
    ind = ind(1);
end

varminc = hdr.variables(ind);
list_att = varminc.attributes;
if nargin == 2
    val = list_att;
    return
end

ind2 = find(ismember(list_att,att_name));
if isempty(ind2)
    error('Could not find attribute %s in variable %s',att_name,var_name)
end
val = varminc.values{ind2};

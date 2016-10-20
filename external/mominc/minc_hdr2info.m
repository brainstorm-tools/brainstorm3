function info_v = minc_hdr2info(hdr)
% Convert a MINC header into a simplified structure
% This is called internally by MINC_READ and not meant to be used by itself.
%
% SYNTAX:
% INFO_V = MINC_HDR2INFO(HDR)
%
% Copyright (c) Pierre Bellec, Centre de recherche de l'institut de
% gériatrie de Montréal, Département d'informatique et de recherche
% opérationnelle, Université de Montréal, 2013.
%
% Maintainer : pierre.bellec@criugm.qc.ca
% See licensing information in the code.
% Keywords : medical imaging, I/O, reader, minc

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


%% Get information on history
if strcmp(hdr.type,'minc1')
    list_global = {hdr.details.globals(:).name};
    ind = find(ismember(list_global,'history'));
    if isempty(ind)
        info_v.history = '';
    else
        info_v.history = hdr.details.globals(ind).values;
    end
else
    info_v.history = hdr.details.globals.history;
end

%% Get information on the order of the dimensions
info_v.dimensions = hdr.dimension_order;

%% For each dimension, get the step, start and cosines information
start_v = zeros([3 1]);
cosines_v = eye([3 3]);
step_v = zeros([1 3]);
info_v.voxel_size = zeros([1 3]);

num_e = 1;

for num_d = 1:length(info_v.dimensions)
    dim_name = info_v.dimensions{num_d};

    if ~strcmp(dim_name,'time')
        if strcmp(hdr.type,'minc1')
            cosines_v(:,num_e) = minc_variable(hdr,dim_name,'direction_cosines');
            start_v(num_e) = minc_variable(hdr,dim_name,'start');
            step_v(num_e) = minc_variable(hdr,dim_name,'step');
        else
            cosines_v(:,num_e) = minc_variable(hdr,dim_name,['/minc-2.0/dimensions/' dim_name '/direction_cosines']);
            start_v(num_e) = minc_variable(hdr,dim_name,['/minc-2.0/dimensions/' dim_name '/start']);
            step_v(num_e) = minc_variable(hdr,dim_name,['/minc-2.0/dimensions/' dim_name '/step']); 
        end        
        num_e = num_e + 1;
    else        
        info_v.tr = minc_variable(hdr,'time','step');
        info_v.t0 = minc_variable(hdr,'time','start');
    end
end

info_v.voxel_size = abs(step_v);

% Constructing the voxel-to-worldspace affine transformation
info_v.mat = eye(4);
info_v.mat(1:3,1:3) = cosines_v * (diag(step_v));
info_v.mat(1:3,4)   = cosines_v * start_v;

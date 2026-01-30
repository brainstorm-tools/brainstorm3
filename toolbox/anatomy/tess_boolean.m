function  [NewTessFile, errMsg] = tess_boolean(TessFiles, Operation)
% TESS_BOOLEAN: Boolean combination of two surface meshes (triangulations).
%
% Performs a set-like boolean operation (union / intersection / difference)
% between **two** input surface files (triangular meshes) using SURFBOOLEAN,
% resolves intersections, and saves the resulting surface as a new Brainstorm
% surface file registered in the database.
%
% USAGE:
%    [NewTessFile, errMsg] = tess_boolean(TessFiles, Operation)
%
% INPUT:
%    - TessFiles  : 1x2 cell-array of full/relative paths to Brainstorm surface
%                  files (.mat) that contain fields: Vertices (Nx3), Faces (Mx3)
%                  Example: {surfFile1, surfFile2}
%    - Operation  : String specifying the boolean operation.
%                  Supported values (aliases):
%                     * 'or'   | 'union'        : surf1 U surf2 (outer surface)
%                     * 'and'  | 'inter'        : surf1 ∩ surf2
%                     * 'diff' | '-'            : surf1 - surf2
%                  If empty or not provided, a GUI dialog prompts the user.
%
% OUTPUT:
%    - NewTessFile : Filename (database-relative) of the newly created surface.
%                   Empty if the operation is cancelled or fails.
%    - errMsg      : Error message string (empty if successful).
%
% NOTES:
%    - This function currently supports **exactly two** input surfaces.
%    - The output may be empty (eg. no intersection); in this case an error is returned.
%    - Output is saved next to the first input surface as: tess_<operation>*.mat
%      and is added to the Brainstorm database with the same SurfaceType as TessFiles{1}.
%
% DEPENDENCIES:
%    - surfboolean()  (Iso2mesh @Qianqian Fang) for mesh boolean operations
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
% Authors: Takfarinas Medani, 2026

% Initialize returned variables
NewTessFile = [];
errMsg = [];

% Initialize new structure
NewTess = db_template('surfacemat');

% Parse inputs
if (nargin < 2) || isempty(Operation)
    Operation = [];
end

%% ===== USER INTERACTION =====
if (nargin < 2) || isempty(Operation)
    operation_str = {'union (surf1 U surf2)', 'intersection (surf1 ∩ surf2)', 'difference (surf1 - surf2)'};
    % Ask method
    ind = java_dialog('radio', 'Select the boolean operation:', 'surface boolean operation', [], operation_str, 1);
    if isempty(ind)
        return
    end
    % Select corresponding method name
    switch (ind)
        case 1,  operation = 'or';
        case 2,  operation = 'and';
        case 3,  operation = 'diff';
    end
end

% Progress bar
bst_progress('start', 'Boolean Operation', operation_str{ind});

% Process all the files to process
if length(TessFiles) > 2
    errMsg = 'This function suports only 2 input surfaces';
    return;
end
% load the surfaces
tess1 = in_tess_bst(TessFiles{1});
tess2 = in_tess_bst(TessFiles{2});
% apply boolean operation
[no, fc] = surfboolean( tess1.Vertices, tess1.Faces, operation,  tess2.Vertices, tess2.Faces);
if isempty(no)
        errMsg = ['The output of this operation is empty'];
    return;
end
% To check
% figure
% plotmesh(no, fc,  'facealpha', 0.4)
% % [nocyl1, fccyl1] = removeisolatednode(no, fc(:, 1:3));
% [nocyl2, fccyl2] = meshcheckrepair(nocyl1, fccyl1);

NewTess.Vertices = no;
NewTess.Faces    = fc;
NewTess.Atlas    = [];
NewTess.iAtlas   = 0;
NewTess.History  = [];
% History: Merged surface #i
NewTess = bst_history('add', NewTess, 'boolean', sprintf('Boolean: [%s] %s [%s]', tess1.Comment, operation, tess2.Comment ));
NewTess.Comment = operation_str{ind};

% ===== SAVE IN DATABASE =====
% Create new filename
NewTessFile = bst_fullfile(bst_fileparts(TessFiles{1}), ['tess_' operation '.mat']);
NewTessFile = file_unique(NewTessFile);
% Save file
bst_save(NewTessFile, NewTess, 'v7');
% Make output filename relative
NewTessFile = file_short(NewTessFile);
% Get subject
[sSubject, iSubject, iFirstSurf] = bst_get('SurfaceFile', TessFiles{1});
% Register this file in Brainstorm database
db_add_surface(iSubject, NewTessFile, NewTess.Comment, sSubject.Surface(iFirstSurf).SurfaceType);
% Close progress bar
bst_progress('stop');

end
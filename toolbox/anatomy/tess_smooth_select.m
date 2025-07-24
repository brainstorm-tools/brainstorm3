function NewTessFile = tess_smooth_select(TessFile, Method, Params)
% TESS_SMOOTH_SELECT: Smooths a surface with different methods
%
% USAGE:  NewTessFile = tess_smooth_select(TessFile, Methods=[ask], Params=[ask]);
%         NewTessMat  = tess_smooth_select(TessMat,  Methods=[ask], Params=[ask]);
%
% INPUT:
%    - TessFile    : Surface file (or surface mat) to smooth
%    - Method      : Method to smooth
%    - Params      : Method specific parameters
%                    List of parameters in the var 'paramFields' below
% OUTPUT:
%    - NewTessFile : New surface file (or surface mat)
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
% Authors: Takfarinas Medani, 2025
%          Raymundo Cassani, 2025

%% ===== PARSE INPUTS =====
if (nargin < 3) || isempty(Params)
    Params = [];
end
if (nargin < 2) || isempty(Method)
    Method = [];
    Params = [];
end

MultipleFiles = [];
% USAGE: tess_smooth_wrapper(TessMat, ...)
if isstruct(TessFile)
    TessMat  = TessFile;
    TessFile = [];
% USAGE: tess_smooth_wrapper({TessFile1, TessFile2}, ...)
elseif iscell(TessFile)
    if (length(TessFile) > 1)
        MultipleFiles = TessFile;
    end
    TessFile = TessFile{1};
% USAGE: tess_smooth_wrapper(TessFile, ...)
elseif ischar(TessFile)
    TessFile = file_short(TessFile);
    TessMat = [];
else
    error('Invalid call.');
end
% Save current modifications
panel_scout('SaveModifications');

% Methods and their parameters {name, description, defValue}
paramFields.brainstorm_laplacian = {'a',           'Scalar smooth weighting (0-1 less-more smoothing)', '0.5'; ...
                                    'nIterations', 'Number of times to apply the smoothing',            '5'};
paramFields.iso2mesh_laplacianhc = {'alpha',       'Smoothing parameter: [0, 1] (0 strong, 1 weak)',    '0.5'; ...
                                    'iter',        'Number of times to apply the smoothing',            '5'};
paramFields.iso2mesh_laplacian   = paramFields.iso2mesh_laplacianhc;
paramFields.iso2mesh_lowpass     = paramFields.iso2mesh_laplacianhc;

%% ===== USER INTERACTION =====
if isempty(Method)
    % Ask for user confirmation
    isConfirm = java_dialog('confirm', [...
        'Warning: This operation will move vertices on the surface.' 10 10 ...
        'If you run it, you have to delete and recalculate the' 10 ...
        'headmodels and source files calculated using this surface.' 10 10 ...
        'Run the surface smoothing now?' 10 10], ...
        'Smooth surface');
    if ~isConfirm
        return
    end

methods_str = ...
    {...
    ['<HTML><B><U> [Default] Brainstorm / Laplacian:</U></B><BR>' ...
    '&nbsp;&nbsp;&nbsp;| - Fast and simple Laplacian smoothing.<BR>' ...
    '&nbsp;&nbsp;&nbsp;| - May cause surface shrinkage on fine structures.<BR>' ...
    '&nbsp;&nbsp;&nbsp;| - Recommended for quick denoising when shape distortion is acceptable.<BR>' ...
    '&nbsp;&nbsp;&nbsp;| - Calls the <CODE>tess_smooth.m</CODE> function.'], ...
    
    ['<HTML><B> iso2mesh / Laplacian:</B><BR>' ...
    '&nbsp;&nbsp;&nbsp;| - Classic Laplacian smoothing, similar to Brainstorm.<BR>' ...
    '&nbsp;&nbsp;&nbsp;| - Fast but may shrink the mesh.<BR>' ...
    '&nbsp;&nbsp;&nbsp;| - Best used for non-critical geometry or preprocessing.<BR>' ...
    '&nbsp;&nbsp;&nbsp;| - Calls the <CODE>sms</CODE> function with method = ''laplacian''.'], ...
    
    ['<HTML><B> iso2mesh / LaplacianHC:</B><BR>' ...
    '&nbsp;&nbsp;&nbsp;| - Shape-preserving variant of Laplacian smoothing.<BR>' ...
    '&nbsp;&nbsp;&nbsp;| - Uses a two-pass scheme (Humphrey Classes) to reduce shrinkage.<BR>' ...
    '&nbsp;&nbsp;&nbsp;| - Good trade-off between speed and geometry preservation.<BR>' ...
    '&nbsp;&nbsp;&nbsp;| - Calls the <CODE>sms</CODE> function with method = ''laplacianhc''.'], ...
    
    ['<HTML><B> iso2mesh / Lowpass:</B><BR>' ...
    '&nbsp;&nbsp;&nbsp;| - Spectral smoothing via low-pass filtering.<BR>' ...
    '&nbsp;&nbsp;&nbsp;| - Best at preserving anatomical shape and reducing high-frequency noise.<BR>' ...
    '&nbsp;&nbsp;&nbsp;| - Slightly slower but ideal for high-quality output.<BR>' ...
    '&nbsp;&nbsp;&nbsp;| - Calls the <CODE>sms</CODE> function with method = ''lowpass''.'], ...
};
    % Ask method
    ind = java_dialog('radio', 'Select the smoothing method:', 'Smooth surface', [], methods_str, 1);
    if isempty(ind)
        return
    end
    % Select corresponding method name
    switch (ind)
        case 1,  Method = 'brainstorm_laplacian';
        case 2,  Method = 'iso2mesh_laplacianhc';
        case 3,  Method = 'iso2mesh_laplacian';
        case 4,  Method = 'iso2mesh_lowpass';
    end
    % Ask for paramaters for each method
    param_desc   = paramFields.(Method)(:,2)';
    param_values = paramFields.(Method)(:,3)';
    % Ask user for parameters
    res = java_dialog('input', param_desc, ['Smooth surface: ' Method], [], param_values);
    if isempty(res)
        return
    else
        for iParam = 1 : numel(res)
            Params.(paramFields.(Method){iParam, 1}) = str2double(res{iParam});
        end
    end
end

%% ===== PROCESS MULTIPLE FILES =====
if ~isempty(MultipleFiles)
    for i = 1:length(MultipleFiles)
        NewTessFile = tess_smooth_wrapper(MultipleFiles{i}, Method, Params);
    end
    return
end

%% ===== SMOOTH =====
% Verify method and parameters
C = setdiff(fieldnames(Params), paramFields.(Method));
if ~isempty(C)
    bst_error(sprintf('Smooth surface: parameters for method %s are not correct, check tess_smooth_select.m', Method));
end

% Progress bar
isProgress = bst_progress('isVisible');
if ~isProgress
    bst_progress('start', 'Smooth surface', 'Loading file...');
end
% Load surface file
if ~isempty(TessFile) && isempty(TessMat)
    TessMat = in_tess_bst(TessFile);
end

newTessMat = db_template('surfacemat');
switch Method
    case 'brainstorm_laplacian'
        % Run tess_smooth smoothing
        isKeepSize = 1;
        newTessMat.Vertices = tess_smooth(TessMat.Vertices, Params.a, Params.nIterations, TessMat.VertConn, isKeepSize, TessMat.Faces);
    case {'iso2mesh_laplacianhc', 'iso2mesh_laplacian', 'iso2mesh_lowpass'}
        % Install/load iso2mesh plugin
        isInstalled = bst_plugin('Install', 'iso2mesh', 1);
        if ~isInstalled
            bst_error('Plugin "iso2mesh" not available.');
        end

        % Some recommendation for curious user
        % | Goal (laplacianhc)      | iter  | alpha (typical) |
        % | ----------------------- | ----- | --------------- |
        % | Light denoise           | 3–5   | 0.3–0.6         |
        % | Moderate smooth         | 8–15  | 0.2–0.4         |
        % | Heavy smooth (careful!) | 20–50 | 0.1–0.3         |
        % [check smoothsurf of iso2mesh for more information]

        % Run the sms smoothing
        iso2meshArgMethod = split(Method,'_');
        newTessMat.Vertices = sms(TessMat.Vertices, TessMat.Faces, Params.iter, Params.alpha, iso2meshArgMethod{2});
end
% Tag to add in the history file
MethodTag = ['Method: ' Method];
for iParam = 1 : size(paramFields.(Method), 1)
    MethodTag = [MethodTag ', ' paramFields.(Method){iParam, 1} ': ' res{iParam}];
end
% Complete missing fields
NewComment = [TessMat.Comment, '_smooth'];
newTessMat.Comment = NewComment;
newTessMat.Faces   = TessMat.Faces;
% Atlas
newTessMat.Atlas   = TessMat.Atlas;
newTessMat.iAtlas  = TessMat.iAtlas;
% History
if isfield(TessMat, 'History')
    newTessMat.History = TessMat.History;
end
newTessMat = bst_history('add', newTessMat, 'Smooth', ['Smooth surface: ' MethodTag] );
if isfield(TessMat, 'Reg')
    newTessMat.Reg = TessMat.Reg;
end

% Save newTessMat in file and register to DB, if a filepath was provided in TessFile
if ~isempty(TessFile)
    % Filename for newTessMat
    [filepath, filebase, fileext] = bst_fileparts(file_fullpath(TessFile));
    NewTessFile = file_unique(bst_fullfile(filepath, [filebase, '_smooth' fileext]));
    % Save smoothed surface file
    bst_save(NewTessFile, newTessMat, 'v7');
    % Make output filename relative
    NewTessFile = file_short(NewTessFile);
    % Get subject
    [~, iSubject] = bst_get('SurfaceFile', TessFile);
    % Register this file in Brainstorm database
    db_add_surface(iSubject, NewTessFile, NewComment);
% Return newTessMat struct
else
    NewTessFile = newTessMat;
end

% Close progress bar
if ~isProgress
    bst_progress('stop');
end
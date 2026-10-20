function errorMsg = import_anatomy_mideface(iSubject, FsDir, nVertices, isInteractive, sMri)
    % IMPORT_ANATOMY_mideface: Import only the head.surf surface produced by MiDeFace
    %
    % USAGE:  errorMsg = import_anatomy_mideface(iSubject, FsDir, nVertices, isInteractive, sFid)
    %
    % INPUT:
    %    - iSubject      : Indice of the subject where to import the MRI
    %                      If iSubject=0 : import MRI in default subject
    %    - FsDir         : Full filename of the FreeSurfer folder to import (MiDeFace is based on FS)
    %    - nVertices     : Number of vertices to use for the head surface
    %    - isInteractive : If 0, no input or user interaction
    %    - sMri          : full MRI structure for subject, to align the head surface with, with
    %                      fiducials defined in the SCS structure
    % OUTPUT:
    %    - errorMsg : String: error message if an error occurs

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
    % Authors: Francois Tadel, Marc Lalancette, 2012-2026

    % Based on import_anatomy_fs.m

    %% ===== PARSE INPUTS =====
    % Initialize returned variable
    errorMsg = [];
    % Interactive / silent
    if (nargin < 4) || isempty(isInteractive)
        isInteractive = 1;
    end
    % MRI
    if (nargin < 5) || isempty(sMri)
        errorMsg = [errorMsg 'sMri required to import MiDeFace head surface.' 10];
        if isInteractive
            bst_error(['Could not import MiDeFace folder: ' 10 10 errorMsg], 'Import MiDeFace', 0);
        end
        return;
    end
    % Ask number of vertices for the cortex surface
    if (nargin < 3) || isempty(nVertices)
        nVertices = [];
    end
    % Ask folder to the user
    if (nargin < 2) || isempty(FsDir)
        % Get default import directory and formats
        LastUsedDirs = bst_get('LastUsedDirs');
        % Open file selection dialog
        FsDir = java_getfile( 'open', ...
            'Import FreeSurfer folder...', ...     % Window title
            bst_fileparts(LastUsedDirs.ImportAnat, 1), ...           % Last used directory
            'single', 'dirs', ...                  % Selection mode
            {{'.folder'}, 'FreeSurfer folder', 'FsDir'}, 0);
        % If no folder was selected: exit
        if isempty(FsDir)
            return
        end
        % Save default import directory
        LastUsedDirs.ImportAnat = FsDir;
        bst_set('LastUsedDirs', LastUsedDirs);
    end
    % Unload everything
    bst_memory('UnloadAll', 'Forced');


    %% ===== ASK NB VERTICES =====
    if isempty(nVertices)
        nVertices = java_dialog('input', 'Number of vertices for the head surface:', 'Import MiDeFace', [], '15000');
        if isempty(nVertices)
            return
        end
        nVertices = str2double(nVertices);
    end


    %% ===== PARSE FREESURFER FOLDER =====
    bst_progress('start', 'Import FreeSurfer folder', 'Parsing folder...');
    % Find surface
    TessFile = file_find(FsDir, 'head.surf', 2);
    if isempty(TessFile)
        % TODO: Look for other head surface files. Need to add loop below if we do this.
        % TessFile = file_find(FsDir, 'head*.surf', 2);        
        errorMsg = [errorMsg 'head.surf file was not found' 10];
    end

    % d = dir(TessFile);
    % if (length(d) == 1) && (d.bytes < 256)
    %     TessFile = [];
    % end

    % Report errors
    if ~isempty(errorMsg)
        if isInteractive
            bst_error(['Could not import MiDeFace folder: ' 10 10 errorMsg], 'Import MiDeFace', 0);
        end
        return;
    end

    [iHead, BstHeadFile] = import_surfaces(iSubject, TessFile, 'MI', 0);
    BstHeadFile = BstHeadFile{1};
    if isempty(BstHeadFile)
        errorMsg = [errorMsg 'Unable to import head.surf.' 10];
        if isInteractive
            bst_error(errorMsg, 'Import MiDeFace', 0);
        end
        return;
    end

    bst_progress('start', 'Import FreeSurfer folder', 'Downsampling: head...');
    % Check if Lidar Toolbox is installed (requires image processing + computer vision)
    isLidarToolbox = exist('surfaceMesh', 'file') == 2;
    if isLidarToolbox
        ReduceMethod = 'simplify'; % doesn't seem to do better: still disconnected bits
    else
        ReduceMethod = 'reducepatch';
    end
    % Methods: 'iso2mesh' avoids disconnected components, but looses surface details.
    % 'simplify' has single vertex linked components, and smooths just a tiny bit vs reducepatch.
    % 'reducepatch' keeps more of the intricate parts, which is not always wanted, and can produce
    % disconnected components.
    BstHeadLowFile = tess_downsize(BstHeadFile, nVertices, ReduceMethod);
    
    if isempty(BstHeadLowFile)
        % Assume it didn't need to downsize, or just use original.
        BstHeadLowFile = BstHeadFile;
    else
        % Load but don't compute missing fields.
        TessMat = in_tess_bst(BstHeadLowFile, 0);
        % Remove disconnected bits, keeping only edge-connected components.
        bst_progress('text', 'Removing small patches...');
        [TessMat.Vertices, TessMat.Faces, iRemoveVert] = tess_remove_small(TessMat.Vertices, TessMat.Faces, [], true);
        nVert = size(TessMat.Vertices, 1);
        TessMat.Comment = sprintf('head_simplify_clean_%dV', nVert);
        % Just empty other fields and recompute later as needed.
        for Field = {'VertConn', 'VertNormals', 'Curvature', 'SulciMap'}
            if isfield(TessMat, Field{1})
                TessMat.(Field{1}) = [];
            end
        end
    end

    % Everything seems ok here in subject and database. 
    % Unload everything. Keep this to be consistent with other "import anatomy" functions.
    bst_memory('UnloadAll', 'Forced');

    % Give a graphical output for user validation
    if isInteractive
        % Display the downsampled cortex + head + ASEG
        hFig = view_surface(BstHeadLowFile);
        % Set orientation
        figure_3d('SetStandardView', hFig, 'left');
    end
    % Close progress bar
    bst_progress('stop');

end


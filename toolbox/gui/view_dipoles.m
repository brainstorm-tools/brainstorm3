function hFig = view_dipoles(DipolesFile, ViewMode)
% VIEW_DIPOLES:  Show dipoles on MRI or cortex surface.
%
% USAGE: hFig = view_dipoles(DipolesFile, ViewMode=[])
%
% INPUTS: 
%    - DipolesFile : Relative path to the dipoles file to open
%    - ViewMode    : {'cortex', 'mri3d', '3d', 'mriviewer'}

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


%%  ===== GET ALL NEEDED INFORMATION =====
global GlobalData;
% ViewMode
if (nargin < 2) || isempty(ViewMode)
    ViewMode = '';
end
% Get study
[sStudy, iStudy, iDip] = bst_get('DipolesFile', DipolesFile);
if isempty(sStudy)
    error('File is not registered in database.');
end
% Get subject
[sSubject, iSubject] = bst_get('Subject', sStudy.BrainStormSubject);
if isempty(sStudy)
    error('Subject is not registered in database.');
end


%% ===== LOAD DIPOLES =====
% Load dipoles file
[iDS, iDipoles] = bst_memory('LoadDipolesFile', DipolesFile, 0);
if isempty(iDS)
    error('Cannot load dipoles file.');
end


%% ===== GET/CREATE FIGURE =====
hFig = [];
% Look for a figure for these dipoles (if display mode is not forced)
if isempty(ViewMode)
    for iFig = 1:length(GlobalData.DataSet(iDS).Figure)
        Figure = GlobalData.DataSet(iDS).Figure(iFig);
        figDipoles     = getappdata(Figure.hFigure, 'Dipoles');
        figDataFile    = getappdata(Figure.hFigure, 'DataFile');
        figResultsFile = getappdata(Figure.hFigure, 'ResultsFile');
        figSubjectFile = getappdata(Figure.hFigure, 'SubjectFile');
        figStudyFile   = getappdata(Figure.hFigure, 'StudyFile');
        % Look for 3DViz figure, without dipoles, and with coherent DataFile / SubjectFile / StudyFile
        if strcmpi(Figure.Id.Type, '3DViz') && isempty(figDipoles) && ...
           (isempty(figDataFile)    || isempty(GlobalData.DataSet(iDS).DataFile) || file_compare(figDataFile, GlobalData.DataSet(iDS).DataFile)) && ...
           (isempty(figResultsFile) || isempty(GlobalData.DataSet(iDS).Dipoles(iDipoles).DataFile) || file_compare(figResultsFile, GlobalData.DataSet(iDS).Dipoles(iDipoles).DataFile)) && ...
           (isempty(figSubjectFile) || file_compare(figSubjectFile, GlobalData.DataSet(iDS).SubjectFile)) && ...
           (isempty(figStudyFile)   || file_compare(figStudyFile, GlobalData.DataSet(iDS).StudyFile))
            hFig = Figure.hFigure;
            ViewMode = '3d';
        end
    end
    % If nothing was found, figure will be created: Add MRI so that the dipoles are not floating in the dark
    if isempty(hFig)
        ViewMode = 'Mri3d';
    end
end
% Create a figure if it has not been done yet
if isempty(hFig) && ~strcmpi(ViewMode, 'mriviewer')
    % Prepare FigureId structure
    FigureId = db_template('FigureId');
    FigureId.Type = '3DViz';
    % Create TimeSeries figure
    [hFig, iFig] = bst_figures('CreateFigure', iDS, FigureId, 'AlwaysCreate');
    if isempty(hFig)
        bst_error('Could not create figure', 'View dipoles', 0);
        return;
    end
end
% % Add information about the loaded files
% if ~isempty(sStudy.Dipoles(iDip).DataFile)
%     % Set the results file
%     ResultsFile = sStudy.Dipoles(iDip).DataFile;
%     setappdata(hFig, 'ResultsFile', ResultsFile);
%     % Try to get the data file
%     [sStudyRes, iStudyRes, iRes] = bst_get('ResultsFile', ResultsFile);
%     if ~isempty(sStudyRes.Result(iRes).DataFile)
%         setappdata(hFig, 'DataFile', sStudyRes.Result(iRes).DataFile);
%     end
% end


%% ===== DISPLAY SURFACE/MRI =====
switch lower(ViewMode)
    case 'mri3d'
        % Get MRI file
        if isempty(sSubject.Anatomy)
            error('No MRI registered for this subject.');
        end
        MriFile = sSubject.Anatomy(sSubject.iAnatomy).FileName;
        % Plot surface 
        hFig = view_mri_3d(MriFile, [], .2, hFig);
        % Load dipoles in figure
        panel_dipoles('AddDipoles', hFig, DipolesFile, 1);
        % Update display
        %panel_dipoles('UpdateDisplayOptions');
        %bst_colormaps('FireColormapChanged');
        
    case 'cortex'
        % Get cortex file
        if isempty(sSubject.iCortex)
            error('No default cortex for this subject.');
        end
        SurfaceFile = sSubject.Surface(sSubject.iCortex).FileName;
        % Plot surface 
        hFigTmp = view_surface(SurfaceFile, .5, [], hFig);
        % Load dipoles in figure
        panel_dipoles('AddDipoles', hFig, DipolesFile, 1);
        % Update display
        %panel_dipoles('UpdateDisplayOptions');
        %bst_colormaps('FireColormapChanged');
        
    case '3d'
        % Load dipoles in figure
        panel_dipoles('AddDipoles', hFig, DipolesFile, 1);
        
    case 'mriviewer'
        % Get MRI file
        if isempty(sSubject.Anatomy)
            error('No MRI registered for this subject.');
        end
        MriFile = sSubject.Anatomy(sSubject.iAnatomy).FileName;
        % Open MRI Viewer 
        [hFig, iDS, iFig] = view_mri(MriFile, DipolesFile);
end

% Make figure visible
set(hFig, 'Visible', 'on');




function varargout = process_ssmooth_surfstat( varargin )
% PROCESS_SSMOOTH_SURFSTAT: Spatial smoothing of the sources using SurfStat (KJ Worsley).

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
% Authors: Peter Donhauser, Francois Tadel, 2015-2016
%          Edouard Delaire, 2023

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Spatial smoothing';
    sProcess.FileTag     = 'ssmooth';
    sProcess.Category    = 'Filter';
    sProcess.SubGroup    = 'Sources';
    sProcess.Index       = 336.1;
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'results', 'timefreq'};
    sProcess.OutputTypes = {'results', 'timefreq'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Default values for some options
    sProcess.isSourceAbsolute = 1;
    sProcess.processDim  = [];    % Do not split matrix

    % Definition of the options
    % === DESCRIPTION
    sProcess.options.help.Comment = ['This process uses SurfStatSmooth (SurfStat, KJ Worsley).<BR><BR>' ...
                                     'The smoothing is based only on the surface topography, <BR>' ...
                                     'not the real geodesic distance between two vertices.<BR>', ...
                                     'The input in mm is converted to a number of edges based<BR>', ...
                                     'on the average distance between two vertices in the surface.<BR><BR>'];
    sProcess.options.help.Type    = 'label';
    % === FWHM (kernel size)
    sProcess.options.fwhm.Comment = '<B>FWHM</B> (Full width at half maximum):  ';
    sProcess.options.fwhm.Type    = 'value';
    sProcess.options.fwhm.Value   = {3, 'mm', 0};
    % === METHOD
    sProcess.options.label.Comment = '<B>Method:</B>';
    sProcess.options.label.Type    = 'label';
    sProcess.options.method.Comment = {'<FONT color="#777777">Before 2023 (not recommended)</FONT>', ...
                                       'Fixed FWHM for all surfaces', ...
                                       'Adjust FWHM for each disconnected surface (slower)'; ...
                                       'before_2023', 'fixed_fwhm', 'adaptive_fwhm'};
    sProcess.options.method.Type    = 'radio_label';
    sProcess.options.method.Value   = 'before_2023';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    % Absolute values 
    if isfield(sProcess.options, 'source_abs') && sProcess.options.source_abs.Value
        strAbs = ',abs';
    else
        strAbs = '';
    end
    % Final comment
    Comment = sprintf('%s (%1.2f mm%s)', sProcess.Comment, sProcess.options.fwhm.Value{1}, strAbs);
end


%% ===== RUN =====
function sInput = Run(sProcess, sInput) %#ok<DEFNU>
    % Get options
    if ~isfield(sProcess.options, 'method') || isempty(sProcess.options.method.Value)
        method = 'before_2023';
    else
        method = sProcess.options.method.Value;
    end
    FWHM = sProcess.options.fwhm.Value{1} / 1000;

    % ===== LOAD DATA =====
    % Load the surface filename from results file
    switch (file_gettype(sInput.FileName))
        case {'results', 'link'}
            FileMat = in_bst_results(sInput.FileName, 0, 'SurfaceFile', 'GridLoc', 'Atlas', 'nComponents', 'HeadModelType');
            nComponents = FileMat.nComponents;
        case 'timefreq'
            FileMat = in_bst_timefreq(sInput.FileName, 0, 'DataType', 'SurfaceFile', 'GridLoc', 'Atlas', 'HeadModelType');
            % Check the data type: timefreq must be source/surface based, and no kernel-based file
            if ~strcmpi(FileMat.DataType, 'results')
                errMsg = 'Only cortical maps can be smoothed.';
                bst_report('Error', 'process_ssmooth_surfstat', sInput.FileName, errMsg);
                return;
            end
            nComponents = 1;
        otherwise
            error('Unsupported file format.');
    end
    % Error: cannot smooth results on volume grids
    if ~strcmpi(FileMat.HeadModelType, 'surface') % ~isempty(FileMat.GridLoc)
        bst_report('Error', sProcess, sInput, 'Spatial smoothing is only supported for surface head models.');
        sInput = [];
        return;
    % Error: cannot smooth results that are already based on atlases
    elseif ~isempty(FileMat.Atlas) && isempty(strfind(sInput.FileName, '_connect1'))
        bst_report('Error', sProcess, sInput, 'Spatial smoothing is not supported for sources based on atlases.');
        sInput = [];
        return;
    % Error: only for constrained sources
    elseif (nComponents ~= 1)
        bst_report('Error', sProcess, sInput, ['This process is only available for source models with constrained orientations.' 10 'With unconstrained orientations, the source maps are usually already very smooth.']);
        sInput = [];
        return;
    end

    % ===== PROCESS =====
    % Smooth surface
    [sInput.A, msgInfo, warmInfo] = compute(FileMat.SurfaceFile, sInput.A, FWHM, method);
    if iscell(msgInfo)
        tmp = sprintf('Smoothing %d independent regions \n',  length(msgInfo));
        for iRegion = 1:length(msgInfo)
            tmp = [tmp,  sprintf('Region %d: %s \n', iRegion, msgInfo{iRegion})];
        end
        msgInfo = tmp;        
    end
    bst_report('Info', sProcess, sInput, msgInfo);
 
    if ~isempty(warmInfo)
        bst_report('Warning', sProcess, sInput, warmInfo);
    end

    % Force the output comment
    sInput.CommentTag = FormatComment(sProcess);
    % Format the output history
    tmp = strsplit(msgInfo,'\n');
    HistoryComment = [sprintf('%s %.1f mm',sProcess.FileTag,FWHM*1000) newline];
    for iLine = 1:length(tmp)
        if ~isempty(tmp{iLine})
            HistoryComment = [HistoryComment ...
                             '|-------- ' strrep(tmp{iLine},'=',':')  newline ];
        end
    end
    if ~isempty(warmInfo)     
        HistoryComment = [HistoryComment ...
                         '|-------- ' warmInfo];
    end

    sInput.HistoryComment = HistoryComment;
end

function [sData, msgInfo, warmInfo] = compute(SurfaceFile, sData, FWHM, version)
    warmInfo = '';

    % Get surface
    if ischar(SurfaceFile)
        SurfaceMat = in_tess_bst(SurfaceFile);
    else
        SurfaceMat = SurfaceFile;
    end

    if strcmp(version,'adaptive_fwhm')
        % Smooth each connenected part of the surface separately
        % first estimate the connected regions 
        nVertices   = size(SurfaceMat.Vertices,1);
        Dist        = bst_tess_distance(SurfaceMat, 1:nVertices, 1:nVertices, 'geodesic_edge');
        subRegions  = process_ssmooth('GetConnectedRegions', SurfaceMat, Dist);
        % Smooth each region separately
        msgInfo    = cell(1,length(subRegions));
        for i = 1:length(subRegions)
            [sData(subRegions(i).Indices,:,:), msgInfo{i}] = compute(subRegions(i), sData(subRegions(i).Indices,:,:), FWHM, 'fixed_fwhm');
        end
        return;
    end
    % Convert surface to SurfStat format
    cortS.tri = SurfaceMat.Faces;
    cortS.coord = SurfaceMat.Vertices';

    % Get the average edge length
    [vi,vj] = find(SurfaceMat.VertConn);
    if strcmp(version,'before_2023')
        Vertices = SurfaceMat.VertConn;
    elseif strcmp(version,'fixed_fwhm')
        Vertices = SurfaceMat.Vertices;
    end

    meanDist = mean(sqrt((Vertices(vi,1) - Vertices(vj,1)).^2 + (Vertices(vi,2) - Vertices(vj,2)).^2 + (Vertices(vi,3) - Vertices(vj,3)).^2));
    
    % FWHM in surfstat is in mesh units: Convert from millimeters to "edges"
    FWHMedge = FWHM ./ meanDist;

    % Display the result of this conversion
    msgInfo = ['Average distance between two vertices: ' num2str(round(meanDist*10000)/10) ' mm' 10 ...
               'SurfStatSmooth called with FWHM=' num2str(round(FWHMedge * 1000)/1000) ' edges'];
    disp(['SMOOTH> ' strrep(msgInfo, char(10), [10 'SMOOTH> '])]); 

    if strcmp(version,'before_2023')
        Vertices = SurfaceMat.Vertices;
        true_meanDist = mean(sqrt((Vertices(vi,1) - Vertices(vj,1)).^2 + (Vertices(vi,2) - Vertices(vj,2)).^2 + (Vertices(vi,3) - Vertices(vj,3)).^2));
        used_FWHM = FWHMedge * true_meanDist;
        
        warmInfo = sprintf('This process is using a FWHM of %.2f mm instead of %.2f mm. Please consult https://github.com/brainstorm-tools/brainstorm3/pull/645 for more information.',used_FWHM*1000,FWHM*1000);
    end

    for iFreq = 1:size(sData,3)
        sData(:,:,iFreq) = SurfStatSmooth(sData(:,:,iFreq)', cortS, FWHMedge)';
    end

end



function varargout = process_ssmooth( varargin )
% PROCESS_SSMOOTH: Spatial smoothing of the sources

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
% Authors: Francois Tadel, 2010-2016        
%          Edouard Delaire, 2023

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Spatial smoothing [2024]';
    sProcess.FileTag     = 'ssmooth';
    sProcess.Category    = 'Filter';
    sProcess.SubGroup    = 'Sources';
    sProcess.Index       = 336;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/VisualGroup';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'results', 'timefreq'};
    sProcess.OutputTypes = {'results', 'timefreq'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Default values for some options
    sProcess.isSourceAbsolute = 1;
    sProcess.processDim  = 2;    % Process time by time
    % === GAUSSIAN PROP
    sProcess.options.label1.Comment = '<U>Gaussian filter properties:</U>';
    sProcess.options.label1.Type    = 'label';
    % === FWHM (kernel size)
    sProcess.options.fwhm.Comment = '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<B>FWHM</B> (Full width at half maximum):  ';
    sProcess.options.fwhm.Type    = 'value';
    sProcess.options.fwhm.Value   = {10, 'mm', 0};
    % === METHOD
    sProcess.options.label2.Comment = '<U>Distance between a pair of vertices:';
    sProcess.options.label2.Type    = 'label';
    sProcess.options.method.Comment = {'<B> Geodesic</B> (mm) <FONT color="#777777">(recommended)</FONT>', ...
                                       '<B> Path length</B> (edges)'; ...
                                       'geodesic_dist', 'geodesic_edge'};
    sProcess.options.method.Type    = 'radio_label';
    sProcess.options.method.Value   = 'geodesic_dist';
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
    Comment = sprintf('%s (%1.2f%s)', sProcess.Comment, sProcess.options.fwhm.Value{1}, strAbs);
end


%% ===== RUN =====
function sInput = Run(sProcess, sInput) %#ok<DEFNU>
    global GlobalData;
    % Get options
    FWHM = sProcess.options.fwhm.Value{1} / 1000; % meters
    Method = sProcess.options.method.Value;

    % ===== LOAD SURFACE =====
    % Load the surface filename from results file
    switch (file_gettype(sInput.FileName))
        case {'results', 'link'}
            FileMat = in_bst_results(sInput.FileName, 0, 'SurfaceFile', 'GridLoc', 'Atlas', 'nComponents', 'HeadModelType');
            nComponents = FileMat.nComponents;
        case 'timefreq'
            FileMat = in_bst_timefreq(sInput.FileName, 0, 'SurfaceFile', 'GridLoc', 'Atlas', 'HeadModelType');
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
    elseif ~isempty(FileMat.Atlas)
        bst_report('Error', sProcess, sInput, 'Spatial smoothing is not supported for sources based on atlases.');
        sInput = [];
        return;
    % Error: only for constrained sources
    elseif (nComponents ~= 1)
        bst_report('Error', sProcess, sInput, ['This process is only available for source models with constrained orientations.' 10 'With unconstrained orientations, the source maps are usually already very smooth.']);
        sInput = [];
        return;
    end

    % ===== COMPUTE SMOOTHING OPERATOR =====
    % Get existing interpolation for this surface
    Signature = sprintf('ssmooth(%1.2f,%s):%s', round(FWHM*1000), Method, FileMat.SurfaceFile);
    WInterp = [];
    if isfield(GlobalData, 'Interpolations') && ~isempty(GlobalData.Interpolations) && isfield(GlobalData.Interpolations, 'Signature')
        iInterp = find(cellfun(@(c)isequal(c,Signature), {GlobalData.Interpolations.Signature}), 1);
        if ~isempty(iInterp)
            WInterp = GlobalData.Interpolations(iInterp).WInterp;
        end
    end
    % Calculate new interpolation matrix
    if isempty(WInterp)
        % Load surface file
        SurfaceMat = in_tess_bst(FileMat.SurfaceFile);
        % Compute the smoothing operator
        WInterp = tess_smooth_sources(SurfaceMat, FWHM, Method);
        % Check for errors
        if isempty(WInterp)
            bst_report('Error', sProcess, sInputs, sprintf('Cannot compute the smoothig %s.', Signature));
            sInput = [];
            return;
        end
        % Save interpolation in memory for future calls
        sInterp = db_template('interpolation');
        sInterp.WInterp   = WInterp;
        sInterp.Signature = Signature;
        if isempty(GlobalData.Interpolations)
            GlobalData.Interpolations = sInterp;
        else
            GlobalData.Interpolations(end+1) = sInterp;
        end
    end

    % ===== APPLY TO THE DATA =====
    % Apply smoothing operator
    for iFreq = 1:size(sInput.A,3)
        sInput.A(:,:,iFreq) = WInterp * sInput.A(:,:,iFreq);
    end
    % Force the output comment
    sInput.CommentTag = [sProcess.FileTag, sprintf(' %.1f %s', FWHM*1000, Method)];
    % Do not keep the Std field in the output
    if isfield(sInput, 'Std') && ~isempty(sInput.Std)
        sInput.Std = [];
    end
end





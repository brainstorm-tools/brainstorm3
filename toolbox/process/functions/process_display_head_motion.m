function varargout = process_display_head_motion(varargin)
  %
  
  % @=============================================================================
  % This function is part of the Brainstorm software:
  % https://neuroimage.usc.edu/brainstorm
  %
  % Copyright (c)2000-2018 University of Southern California & McGill University
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
  % Authors: Marc Lalancette, 2018
  
  eval(macro_method);
end



%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
  % Description of the process
  sProcess.Comment     = 'Display head motion (CTF)';
  sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/HeadMotion';
  sProcess.Category    = 'Custom';
  sProcess.SubGroup    = 'Events';
  sProcess.Index       = 70;
  % Input accepted by this process
  sProcess.InputTypes  = {'raw', 'data'};
  sProcess.OutputTypes = {'', ''};
  sProcess.nInputs     = 1;
  sProcess.nMinFiles   = 1;
  % Options
  sProcess.options.warning.Comment = 'Only for CTF MEG recordings with HLC channels recorded.<BR><BR>';
  sProcess.options.warning.Type    = 'label';
  
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInput) %#ok<STOUT,INUSL,DEFNU>
  % Plot head motion as distance from reference (initial) position
  
    % Load the raw file descriptor
    isRaw = strcmpi(sInput.FileType, 'raw');
    if isRaw
      DataMat = in_bst_data(sInput.FileName, 'F', 'Time');
      sFile = DataMat.F;
    else
      DataMat = in_bst_data(sInput.FileName, 'Time');
      sFile = in_fopen(sInput.FileName, 'BST-DATA');
    end
    %     % Process only continuous files for now.
    %     if ~isempty(sFile.epochs)
    %       bst_report('Error', sProcess, sInput, 'This function can only process continuous recordings (no epochs).');
    %       return;
    %     end
        
    % Load head coil locations, in m.
    % Initial location, from .hc file.
    InitLoc = [sFile.header.hc.SCS.NAS, sFile.header.hc.SCS.LPA, ...
      sFile.header.hc.SCS.RPA]';
    % Continuous head localization, from HLU channels.
    ReshapeToContinuous = true;
    [Locations, HeadSamplePeriod, FitErrors] = ...
      process_evt_head_motion('LoadHLU', sInput, ReshapeToContinuous);
    nSxnT = size(Locations, 2);
    %     nT = size(Locations, 3);
    
    % Get motion distance from reference location, as most distant point
    % on a sphere that follows the motion defined by the head coils.
    % This replaces the 9 HLU channels and better captures any type of
    % head movement.
    tic
    D = process_evt_head_motion('RigidDistances', Locations, InitLoc);
    toc
    
    % Upsample back to MEG sampling rate.
    tic
    D = interp1(D, 1:nSxnT*HeadSamplePeriod);
    %     D = resample(D, HeadSamplePeriod, 1);
    toc
    
    % Display
    figure();
    Time = ((1:nSxnT*HeadSamplePeriod)' - 1) / sFile.prop.sfreq + ...
      DataMat.Time(1);
    plot(Time, D);
    
    % Optionnally display head coil fit errors.
    DoFit = false;
    if DoFit
      % Use maximum error among coils.
      FitErrors = max(FitErrors);
      FitErrors = interp1(FitErrors, 1:nSxnT*HeadSamplePeriod);
      %       FitErrors = resample(FitErrors, HeadSamplePeriod, 1);
      figure();
      plot(Time, FitErrors);
    end
        
  end



  
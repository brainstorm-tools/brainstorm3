function varargout = process_fix_headcoils(varargin)
% PROCESS_FIX_HEADCOILS: Estimate the position of a missing or bad head localization coil.

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2020 University of Southern California & McGill University
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
% Authors: Marc Lalancette, 2020

eval(macro_method);
end



function sProcess = GetDescription() %#ok<DEFNU>
    % Description of the process
    sProcess.Comment     = 'Fix bad head coil (CTF)';
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/HeadMotion#Dealing_with_a_missing_or_bad_head_coil';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = {'Import', 'Channel file'};
    sProcess.Index       = 54;
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw', 'data'};
    sProcess.OutputTypes = {'raw', 'data'};
    sProcess.nInputs     = 2;
    sProcess.nOutputs    = 1;
    sProcess.nMinFiles   = 1;
    sProcess.isSeparator = 0;
    sProcess.isPaired    = 1;
    sProcess.FileTag     = 'fix';
    
    % Options
    % === Sensor types
    sProcess.options.sensortypes.Comment = 'Sensor types or names (empty=all): ';
    sProcess.options.sensortypes.Type    = 'text';
    sProcess.options.sensortypes.Value   = {'HLU'};
    sProcess.options.sensortypes.Hidden  = 1;
    %     sProcess.options.read_all.Comment    = ''; % Automatically added to filter-type processes.
    %     sProcess.options.read_all.Type       = 'checkbox';
    %     sProcess.options.read_all.Value      = 1;
    %     sProcess.options.read_all.Hidden     = 1;
    
    sProcess.processDim = 2; % Only split by column blocks, if needed.
    
    sProcess.options.BadCoil.Type    = 'radio_line';
    sProcess.options.BadCoil.Comment = {'Nasion', 'Left ear', 'Right ear', 'Bad coil: '};
    sProcess.options.BadCoil.Value   = 1;
    %     sProcess.options.label1.Type    = 'label';
    %     sProcess.options.label1.Comment = '<B>How will you provide a "good and similar" head position?</B>';
    %     sProcess.options.GoodSource.Type    = 'radio';
    %     sProcess.options.GoodSource.Comment = {'Recording already in Brainstorm', 'Raw recording file', 'Manual entry of <B>dewar</B> coordinates'};
    %     sProcess.options.GoodSource.Value   = 1;
    %     sProcess.options.display.Type    = 'checkbox';
    %     sProcess.options.display.Comment = 'Display "before" and "after" alignment figures.';
    %     sProcess.options.display.Value   = 0;
    
end



function Comment = FormatComment(sProcess)
    Comment = [sProcess.Comment, ': ', ...
        sProcess.options.BadCoil.Comment{sProcess.options.BadCoil.Value}];
    
end



function OutputFiles = Run(sProcess, sInputA, sInputB)
    
    % If called from ProcessFilter
    if isfield(sProcess, 'FromProcessFilter') && sProcess.FromProcessFilter
            OutputFiles = [];
            ChannelMat = in_bst_channel(sInputA.ChannelFile);
            
           % Check the input is CTF.
            DataMat = in_bst_data(sInputA.FileName, 'Device');
            if ~strcmp(DataMat.Device, 'CTF')
                bst_report('Error', sProcess, sInputA, ...
                    'Fix bad head coil is currently only available for CTF data.');
                return;
            end
            
            % Difficult to find the initial head sample in each epoch. And
            % if wrong, fixed HLU channel will have offset "steps". So
            % process redundant samples, which we would need to recreate
            % anyway.
            %             % Load head coil locations, in m.
            %             bst_progress('text', 'Loading head coil locations...');
            %             [Locations, HeadSamplePeriod] = process_evt_head_motion('LoadHLU', sInputA, [], false); % [nChannels, nSamples, nEpochs]
            %             if isempty(Locations)
            %                 % No HLU channels. Error already reported. Skip this file.
            %                 return;
            %             end
            bst_progress('text', 'Correcting head position...');
            % Sort in case coils were swapped.
            [Unused, iSortHlu] = sort({ChannelMat.Channel(strcmp({ChannelMat.Channel.Type}, 'HLU')).Name});
            
            % Compute
            GoodAxis = sInputA.A(iSortHlu(sProcess.Ext.iGood(1:3)), :, :) - sInputA.A(iSortHlu(sProcess.Ext.iGood(4:6)), :, :); %[3, nS, nE]
            GoodAxis = bsxfun(@rdivide, GoodAxis, sqrt(sum(GoodAxis.^2, 1)));
            FixedCoil = (sInputA.A(iSortHlu(sProcess.Ext.iGood(4:6)), :, :) + sInputA.A(iSortHlu(sProcess.Ext.iGood(1:3)), :, :)) ./ 2 + ...
                GoodAxis * sProcess.Ext.BadAlongGoodAxis + bsxfun(@cross, GoodAxis, sProcess.Ext.Normal) * sProcess.Ext.BadFromGoodAxis;
            % If a collection was aborted, the channels will be filled with
            % zeros. The "fixed" data will contain NaN, change them back to 0.
            FixedCoil(isnan(FixedCoil)) = 0;
            
            %             % Re-upsample (duplicate) and save new data.
            %             [n3, nHeadSamples, nEpochs] = size(FixedCoil);
            %             FixedCoil = reshape(permute(FixedCoil, [2, 3, 1]), [], 1);
            %             FixedCoil = permute(reshape(FixedCoil(:, ones(1,HeadSamplePeriod))', [], nEpochs, n3), [3, 1, 2]);

            %             [nChan, nSamples, nEpochs] = size(sInputA.A);
            %             sInputA.A(iSortHlu(sProcess.Ext.iBad), :, :) = FixedCoil(:, 1:nSamples, 1:nEpochs);
            sInputA.A(iSortHlu(sProcess.Ext.iBad), :, :) = FixedCoil;
            OutputFiles = sInputA;
            
    % Initial call from pipeline
    else 
        OutputFiles = {sInputA.FileName};
        % Flag to indicate Run will be called by ProcessFilter.
        sProcess.FromProcessFilter = 1;
        
        % Bad coil
        sProcess.Ext.iBad = (1:3) + (sProcess.options.BadCoil.Value - 1) * 3;
        % Good coils
        sProcess.Ext.iGood = setdiff(1:9, sProcess.Ext.iBad);
        
        bst_progress('start', 'Fix bad head coil', ' ', 0, numel(sInputA));
        
        % Process each input file pair.
        for iFile = 1:length(sInputA)
            % [Possibly to add: options to load from external file or prompt for manual entry, showing current (bad) dewar coordinates.]
            % Get good head coil Dewar coordinates from second channel file.
            ChannelMatB = in_bst_channel(sInputB(iFile).ChannelFile);
            sProcess.Ext.RefLoc = process_adjust_coordinates('ReferenceHeadLocation', ChannelMatB);
            % Sort in case coils were swapped.
            [Unused, iSortHlu] = sort({ChannelMatB.Channel(strcmp({ChannelMatB.Channel.Type}, 'HLU')).Name});
            
            % Get relative coordinates of the bad coil from the external source.
            sProcess.Ext.CoilA = sProcess.Ext.RefLoc(iSortHlu(sProcess.Ext.iGood(1:3)));
            sProcess.Ext.CoilB = sProcess.Ext.RefLoc(iSortHlu(sProcess.Ext.iGood(4:6)));
            sProcess.Ext.Orig = (sProcess.Ext.CoilA + sProcess.Ext.CoilB) / 2;
            sProcess.Ext.GoodAxis = sProcess.Ext.CoilA - sProcess.Ext.CoilB;
            sProcess.Ext.GoodAxis = sProcess.Ext.GoodAxis ./ norm(sProcess.Ext.GoodAxis);
            sProcess.Ext.BadFromO = sProcess.Ext.RefLoc(iSortHlu(sProcess.Ext.iBad)) - sProcess.Ext.Orig;
            sProcess.Ext.BadAlongGoodAxis = sProcess.Ext.BadFromO' * sProcess.Ext.GoodAxis;
            sProcess.Ext.BadFromGoodAxis = norm(sProcess.Ext.BadFromO - sProcess.Ext.BadAlongGoodAxis * sProcess.Ext.GoodAxis);
            sProcess.Ext.Normal = cross(sProcess.Ext.BadFromO, sProcess.Ext.GoodAxis);
            sProcess.Ext.Normal = sProcess.Ext.Normal ./ norm(sProcess.Ext.Normal);
            % Capture process crashes
            try
                OutputFiles{iFile} = bst_process('ProcessFilter', sProcess, sInputA(iFile));
                bst_progress('inc', 1);
            catch
                strError = bst_error();
                bst_report('Error', sProcess, [sInputA(iFile), sInputB(iFile)], strError);
                continue;
            end
            
        end
        bst_progress('stop');
        
        % Attempt to adjust the initial/reference head position.
        %             ChannelMat = in_bst_channel(sInputA(iFile).ChannelFile);
        %             sOutput = in_bst_data(
        OutputFiles = bst_process('CallProcess', 'process_adjust_coordinates', OutputFiles, [], ...
            'reset', 0, 'head', 1, 'bad', 1, 'points', 0, 'remove', 0, 'display', 1);
        %             [ChannelMat, Failed] = process_adjust_coordinates('AdjustHeadPosition', ...
        %                 ChannelMat, OutputFiles(iFile), sProcess);
        %             if ~Failed
        %                 % Save channel file.
        %                 bst_save(file_fullpath(OutputFiles(iFile).ChannelFile), ChannelMat, 'v7');
        %                 % Show new alignment.
        %                 channel_align_manual(OutputFiles(iFile).ChannelFile, 'MEG', 0);
        %             % else already noted in report.
        %             end
    end % "called from" if
end






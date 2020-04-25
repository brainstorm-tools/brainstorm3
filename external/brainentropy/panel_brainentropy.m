function varargout = panel_brainentropy(varargin)
% PANEL_BRAINENTROPY: Options for BrainEntropy MEM.
% 
% USAGE:  bstPanelNew = panel_brainentropy('CreatePanel')
%                   s = panel_brainentropy('GetPanelContents')
%
%% ==============================================   
% Copyright (C) 2012 - LATIS Team
%
%  Authors: LATIS, 2012
%
%% ==============================================
% License 
%
% BEst is free software: you can redistribute it and/or modify
%    it under the terms of the GNU General Public License as published by
%    the Free Software Foundation, either version 3 of the License, or
%    (at your option) any later version.
%
%    BEst is distributed in the hope that it will be useful,
%    but WITHOUT ANY WARRANTY; without even the implied warranty of
%    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%    GNU General Public License for more details.
%
%    You should have received a copy of the GNU General Public License
%    along with BEst. If not, see <http://www.gnu.org/licenses/>.
% -------------------------------------------------------------------------   


eval(macro_method);

end


%% ===== CREATE PANEL =====
function [bstPanelNew, panelName] = CreatePanel(OPTIONS,varargin)  %#ok<DEFNU> 

    panelName       =   'InverseOptionsMEM';
    bstPanelNew     =   [];
    
    % Check caller
    firstCall   =   1;
    if numel(varargin)>0 & ischar(varargin{1}) & strcmp(varargin{1},'internal')
        % Internal call, nothing to do
        firstCall   =   0;
        caller      =   'internal';           
    elseif isfield(OPTIONS, 'Comment') & strcmp(OPTIONS.Comment,'Compute sources: BEst')
        % Call from the process, find the right options
        clear global MEMglobal            
        OPTIONS     =   OPTIONS.options.mem.Value; 
        caller      =   'process';
    elseif numel(varargin)==0
        % Call from the GUI, do nothing
        clear global MEMglobal  
        caller      =   'gui';
    else
        % Unexpected call
        fprintf('\n\n***\tError in call to panel_brainentropy\t***\n\tPlease report this bug to: latis@gmail.com\n\n')
        return
    end       

    % ====      CHECK INSTALLATION      ==== %
    if firstCall        
        [bug,warn,version,last_update]     =   be_install;
        if ~isempty(bug)
            fprintf('\n\n***\tError installing BEst\t***\n\t%s\n\n', bug)
            return
        end
        if ~isempty(warn)
            fprintf('\n\n***\tWarning: BEst\t***\n\t%s\n\tToolbox can still be used\n\n', warn)        
        end 
    end
    
	global MEMglobal
    % Java initializations
    import java.awt.*;
    import javax.swing.*;
    % Constants
    TEXT_WIDTH  = 60;
    DEFAULT_HEIGHT = 20;
    % Create main main panel
    jPanelNew = gui_river();
    jPanelNewL = gui_river();
    
    
    %% --------------------- REGULAR OPTIONS PANEL --------------------- %%
    
        % ===== MEM METHOD =====
        JPanelMemType = gui_river([1,1], [0, 6, 6, 6], 'MEM type');
        jButtonGroupMemType = ButtonGroup();
        
        % Version
        if firstCall
            OPTIONS.automatic.version       =   version;
            OPTIONS.automatic.last_update   =   last_update;
        end
        jTXTver =   JTextField(OPTIONS.automatic.version);
        jTXTupd =   JTextField(OPTIONS.automatic.last_update);
        
        
        % MEM : Default (RadioButton)
        jMEMdef =   JRadioButton('cMEM', strcmp(OPTIONS.mandatory.pipeline,'cMEM') );
        hndl    =   handle(jMEMdef, 'callbackproperties');
        set(hndl, 'ActionPerformedCallback', @(h,ev)SwitchPipeline());
        %java_setcb(jMEMdef, 'ActionPerformedCallback', @(h,ev)SwitchPipeline());
        jMEMdef.setToolTipText('<HTML><B>Default MEM</B>:<BR>temporal series</HTML>');
        jButtonGroupMemType.add(jMEMdef);
        JPanelMemType.add('br',jMEMdef);
        JPanelMemType.add('tab', JLabel('(time series representation)'));
        
        % MEM : wMEM (RadioButton)
        JPanelMemType.add('br', JLabel(''));
        jMEMw = JRadioButton('wMEM', strcmp(OPTIONS.mandatory.pipeline,'wMEM') );
        hndl    =   handle(jMEMw, 'callbackproperties');
        set(hndl, 'ActionPerformedCallback', @(h,ev)SwitchPipeline());
        %java_setcb(jMEMw, 'ActionPerformedCallback', @(h,ev)SwitchPipeline());
        jMEMw.setToolTipText('<HTML><B>wavelet-MEM</B>:<BR>targets strong oscillatory source activity<BR>(MEM on discrete time-scale boxes)</HTML>');
        jButtonGroupMemType.add(jMEMw);
        JPanelMemType.add('br', jMEMw);
        JPanelMemType.add('tab', JLabel('(time-scale representation)'));
        
        % MEM : rMEM (RadioButton)
        JPanelMemType.add('br', JLabel(''));
        jMEMr = JRadioButton('rMEM', strcmp(OPTIONS.mandatory.pipeline,'rMEM') );
        hndl    =   handle(jMEMr, 'callbackproperties');
        set(hndl, 'ActionPerformedCallback', @(h,ev)SwitchPipeline());
        %java_setcb(jMEMr, 'ActionPerformedCallback', @(h,ev)SwitchPipeline());
        jMEMr.setToolTipText('<HTML><B>ridge-MEM</B>:<BR>targets strong synchronous souce activity<BR>(MEM on ridge signals of AWT)</HTML>');
        jButtonGroupMemType.add(jMEMr);
        JPanelMemType.add('br', jMEMr);
        JPanelMemType.add('tab', JLabel('(wavelet representation)'));
        
        % Add 'Method' panel to main panel (jPanelNew)
        jPanelNewL.add('br hfill', JPanelMemType);
        
        
        
        % ===== PARAMETERS =====
        if isfield(OPTIONS.mandatory, 'pipeline') && any( strcmp(OPTIONS.mandatory.pipeline, {'cMEM','wMEM','rMEM'}) )
            
            MEMglobal.first_instance    =   0;
            JPanelparam = gui_river([1,1], [0, 6, 6, 6], 'Data definition');
            % ===== TIME SEGMENT =====
            JPanelparam.add('br', JLabel(''));
            jLabelTime = JLabel('Time window: ');
            jLabelTime.setToolTipText('<HTML><B>Time window</B>:<BR>Define a window of interest within the data<BR>(localize only relevant activity)</HTML>');
            JPanelparam.add(jLabelTime);
            % START
            jTextTimeStart = JTextField( num2str(OPTIONS.optional.TimeSegment(1)) );
            jTextTimeStart.setPreferredSize(Dimension(TEXT_WIDTH, DEFAULT_HEIGHT));
            jTextTimeStart.setHorizontalAlignment(JTextField.RIGHT);
            hndl    =   handle(jTextTimeStart, 'callbackproperties');
            set(hndl, 'FocusLostCallback', @(src,ev)check_time('time', '', ''));
            %set(jTextTimeStart, 'FocusLostCallback', @(src,ev)check_time('time', '', ''));
            JPanelparam.add(jTextTimeStart);
            % STOP
            JPanelparam.add(JLabel('-'));
            jTextTimeStop = JTextField( num2str(OPTIONS.optional.TimeSegment(2)) );
            jTextTimeStop.setPreferredSize(Dimension(TEXT_WIDTH, DEFAULT_HEIGHT));
            jTextTimeStop.setHorizontalAlignment(JTextField.RIGHT);
            hndl    =   handle(jTextTimeStop, 'callbackproperties');
            set(hndl, 'FocusLostCallback', @(src,ev)check_time('time', '', ''));
            %set(jTextTimeStop, 'FocusLostCallback', @(src,ev)check_time('time', '', ''));
            JPanelparam.add(jTextTimeStop);
            JPanelparam.add(JLabel('s'));
            
            % Separator
            JPanelparam.add('br', JLabel(''));
            gui_component('label', JPanelparam, [], ' ');
            jsep = gui_component('label', JPanelparam, 'br hfill', ' ');
            jsep.setBackground(java.awt.Color(.4,.4,.4));
            jsep.setOpaque(1);
            jsep.setPreferredSize(Dimension(1,1));
            gui_component('label', JPanelparam, 'br', '');
            
            % ===== TIME BASELINE =====
            JPanelparam.add('br', JLabel('Baseline'));
            jButtonGroupBslType = ButtonGroup();
            JPanelparam.add('br', JLabel(''));
            
            % Default
            jRadioBslDefault = JRadioButton('default (baseline dataset)', 0);
            java_setcb(jRadioBslDefault, 'ActionPerformedCallback', @(h,ev)load_default_baseline );
            jRadioBslDefault.setToolTipText('<HTML><B>Default dataset</B>:<BR>Found a dataset named baseline in the same study</HTML>');
            jButtonGroupBslType.add(jRadioBslDefault);
            JPanelparam.add(jRadioBslDefault);
            JPanelparam.add('br', JLabel(''));
            
            % Within data
            jRadioBslWithin = JRadioButton('within data', 0);
            java_setcb(jRadioBslWithin, 'ActionPerformedCallback', @(h,ev)check_time('bsl', 'within', 'true', 'checkOK') );
            jRadioBslWithin.setToolTipText('<HTML><B>Within data</B>:<BR>Please specify time window for baseline within data</HTML>');
            jButtonGroupBslType.add(jRadioBslWithin);
            JPanelparam.add(jRadioBslWithin);
            JPanelparam.add('br', JLabel(''));
            
            % Import
            jRadioBslImport = JRadioButton('', 0);
            java_setcb(jRadioBslImport, 'ActionPerformedCallback', @(h,ev)import_baseline );
            jBSLflnm = JTextField('Select file:');
            jBSLflnm.setToolTipText('<HTML><B>Baseline file</B>:<BR>Type in complete filename here or import using GUI</HTML>');
            jButtonGroupBslType.add(jRadioBslImport);
            JPanelparam.add(jRadioBslImport);
            JPanelparam.add('hfill', jBSLflnm);
            jbslfl = gui_component('button', JPanelparam, '', 'import');
            hndl    =   handle(jbslfl, 'callbackproperties');
            set(hndl, 'ActionPerformedCallback', @import_baseline);
            %set(jbslfl, 'ActionPerformedCallback', @import_baseline);
            jbslfl.setPreferredSize(Dimension(TEXT_WIDTH+20, DEFAULT_HEIGHT+2));
            
            JPanelparam.add('br', JLabel(''));
            JPanelparam.add(JLabel('Window:         '));
            
            % Baseline START
            jTextBSLStart = JTextField( num2str(OPTIONS.optional.BaselineSegment(1)) );
            jTextBSLStart.setPreferredSize(Dimension(TEXT_WIDTH, DEFAULT_HEIGHT));
            jTextBSLStart.setHorizontalAlignment(JTextField.RIGHT);
            hndl    =   handle(jTextBSLStart, 'callbackproperties');
            set(hndl, 'FocusLostCallback', @(src,ev)check_time('bsl', '', ''));
            %set(jTextBSLStart, 'FocusLostCallback', @(src,ev)check_time('bsl', '', ''));
            JPanelparam.add(jTextBSLStart);
            % Baseline STOP
            JPanelparam.add(JLabel('-'));
            jTextBSLStop = JTextField( num2str(OPTIONS.optional.BaselineSegment(2)) );
            jTextBSLStop.setPreferredSize(Dimension(TEXT_WIDTH, DEFAULT_HEIGHT));
            jTextBSLStop.setHorizontalAlignment(JTextField.RIGHT);
            hndl    =   handle(jTextBSLStop, 'callbackproperties');
            set(hndl, 'FocusLostCallback', @(src,ev)check_time('bsl', '', ''));
            %set(jTextBSLStop, 'FocusLostCallback', @(src,ev)check_time('bsl', '', ''));
            JPanelparam.add(jTextBSLStop);
            JPanelparam.add('tab', JLabel('s'));
            
            % Add 'Method' panel to main panel (jPanelNew)
            jPanelNewL.add('br hfill', JPanelparam);
            
        else
            
            MEMglobal                   =   struct;
            MEMglobal.first_instance    =   1;
                           
            % put references
            JPanelparam = gui_river([1,1], [0, 6, 6, 6], 'References:');
            
            % Amblard
            JPanelparam.add('br', JLabel(''));
            ml = JPanelparam.add('br', JLabel('MEM for neuroimaging:')); ml.setForeground(java.awt.Color(1,0,0));
            JPanelparam.add('br', JLabel('Amblard, Lapalme, and Lina (2004)'));
            JPanelparam.add('br', JLabel('IEEE TBME, 55(3): 427-442'));
            JPanelparam.add('br hfill', JLabel(' '));
            
            %Separator
            jsep = gui_component('label', JPanelparam, 'br hfill', ' ');
            jsep.setBackground(java.awt.Color(.4,.4,.4));
            jsep.setOpaque(1);
            jsep.setPreferredSize(Dimension(1,1));
            JPanelparam.add('br', JLabel(' '));
            
            % Grova
            JPanelparam.add('br', JLabel(''));
            ml = JPanelparam.add('br', JLabel('MEM on simulated spikes:')); ml.setForeground(java.awt.Color(1,0,0));
            JPanelparam.add('br', JLabel('Grova, Daunizeau, Lina, Benar, Benali and Gotman (2006)'));
            JPanelparam.add('br', JLabel('Neuroimage 29 (3), 734-753, 2006'));
            JPanelparam.add('br', JLabel(' '));
            
            %Separator
            jsep = gui_component('label', JPanelparam, 'br hfill', ' ');
            jsep.setBackground(java.awt.Color(.4,.4,.4));
            jsep.setOpaque(1);
            jsep.setPreferredSize(Dimension(1,1));
            JPanelparam.add('br', JLabel(' '));
            
            % Chowdhury
            JPanelparam.add('br', JLabel(''));
            ml = JPanelparam.add('br', JLabel('cMEM on epileptic spikes:')); ml.setForeground(java.awt.Color(1,0,0));
            JPanelparam.add('br', JLabel('Chowdhury, Lina, Kobayashi and Grova (2013)'));
            JPanelparam.add('br', JLabel('PLoS One vol.8(2), e55969'));
            JPanelparam.add('br', JLabel(' '));
            
            %Separator
            jsep = gui_component('label', JPanelparam, 'br hfill', ' ');
            jsep.setBackground(java.awt.Color(.4,.4,.4));
            jsep.setOpaque(1);
            jsep.setPreferredSize(Dimension(1,1));
            JPanelparam.add('br', JLabel(' '));

            % Lina
            JPanelparam.add('br', JLabel(''));
            ml = JPanelparam.add('br', JLabel('wMEM on epileptic spikes:')); ml.setForeground(java.awt.Color(1,0,0));
            JPanelparam.add('br', JLabel('Lina, Chowdhury, Lemay, Kobayashi and Grova (2012)'));
            JPanelparam.add('br', JLabel('IEEE TBME 61(8):2350-2364, 2014'));
            JPanelparam.add('br', JLabel(' '));
            
            %Separator
            jsep = gui_component('label', JPanelparam, 'br hfill', ' ');
            jsep.setBackground(java.awt.Color(.4,.4,.4));
            jsep.setOpaque(1);
            jsep.setPreferredSize(Dimension(1,1));
            JPanelparam.add('br', JLabel(' '));
            
            % Zerouali
            JPanelparam.add('br', JLabel(''));
            ml = JPanelparam.add('br', JLabel('rMEM on cognitive data:')); ml.setForeground(java.awt.Color(1,0,0));
            JPanelparam.add('br', JLabel('Zerouali, Herry, Jemel and Lina (2011)'));
            JPanelparam.add('br', JLabel('IEEE TBME 60(3):770-780, 2011'));
            JPanelparam.add('br', JLabel(' '));
                        
            
            jfakebutton = JRadioButton('fake', 0 );
            jTextTimeStart = jfakebutton;
            jTextTimeStop = jfakebutton;            
            jRadioBslDefault = jfakebutton;
            jRadioBslWithin = jfakebutton;
            jRadioBslImport = jfakebutton;
            jbslfl = jfakebutton;
            jTextBSLStart = jfakebutton;
            jTextBSLStop = jfakebutton;
            jBSLflnm    =   jfakebutton;
											
										   
			
            
            % Add 'Method' panel to main panel (jPanelNew)
            jPanelNewL.add('br hfill', JPanelparam);
        end
        
        % ===== WAVELET OPTIONS ====
        if jMEMw.isSelected()
            JPanelnwav = gui_river([1,1], [0, 6, 6, 6], 'Oscillations options');
            % Scales
            jBoxWAVsc  = JComboBox({''});
            jBoxWAVsc.setPreferredSize(Dimension(TEXT_WIDTH+60, DEFAULT_HEIGHT));
            jBoxWAVsc.setToolTipText('<HTML><B>Analyzed scales</B>:<BR>vector = analyze scales in vector<BR>integer = analyze scales up to integer<BR>0 = analyze all scales</HTML>');        
            jBoxWAVsc.setEditable(1);
            hndl    =   handle(jBoxWAVsc, 'callbackproperties');
            set(hndl, 'ActionPerformedCallback', @(src,ev)rememberTFindex('scales') );
            %set(jBoxWAVsc, 'ActionPerformedCallback', @(src,ev)rememberTFindex('scales') );
            JPanelnwav.add('p left', JLabel('Scales analyzed') );
            JPanelnwav.add('tab hfill', jBoxWAVsc);
            
            if ~firstCall
                jPanelNewL.add('br hfill', JPanelnwav); 
            end
            
        elseif jMEMr.isSelected()
            JPanelnwav = gui_river([1,1], [0, 6, 6, 6], 'Synchrony options');
            % RDG frq rng
            jTxtRfrs  = JComboBox( {''} );  
            jTxtRfrs.setPreferredSize(Dimension(TEXT_WIDTH+30, DEFAULT_HEIGHT));
            jTxtRfrs.setToolTipText('<HTML><B>Ridge frequency band</B>:<BR>delta=1-3, theta=4-7, alpha=8-12, beta=13-30, gamma=31-100<BR>(type in either a string or a frequency range) </HTML>');        
            jTxtRfrs.setEditable(1);
            hndl    =   handle(jTxtRfrs, 'callbackproperties');
            set(hndl, 'ActionPerformedCallback', @(src,ev)rememberTFindex('freqs') );
            %set(jTxtRfrs, 'ActionPerformedCallback', @(src,ev)rememberTFindex('freqs') );
            JPanelnwav.add('p left', JLabel('Frequency (Hz)') );
            JPanelnwav.add('tab', jTxtRfrs);
            % RDG min dur
            jTxtRmd  = JTextField( num2str(OPTIONS.ridges.min_duration) );
            jTxtRmd.setPreferredSize(Dimension(TEXT_WIDTH+30, DEFAULT_HEIGHT));
            jTxtRmd.setHorizontalAlignment(JTextField.RIGHT);
            jTxtRmd.setToolTipText('<HTML><B>Arbitrary threshold on ridges duration (ms)<BR>(ridges shorter than this threshold will be discarded)</HTML>');        
            JPanelnwav.add('p left', JLabel('Duration (ms)') );
            JPanelnwav.add('tab', jTxtRmd);
            
            if ~firstCall
                jPanelNewL.add('br hfill', JPanelnwav); 
            end
        end                   
            
        % ===== CLUSTERING METHOD =====
        JPanelCLSType = gui_river([1,1], [0, 6, 6, 6], 'Clustering');
             
        
        % Method
        jButtonGroupCLS = ButtonGroup();
        % Clustering : Dynamic (RadioButton)
        JPanelCLSType.add('br', JLabel(''));
        jRadioDynamic = JRadioButton('Dynamic (blockwise)', strcmp(OPTIONS.clustering.clusters_type,'blockwise') );
        java_setcb(jRadioDynamic, 'ActionPerformedCallback', @(h,ev)UpdatePanel());
        jRadioDynamic.setToolTipText('<HTML><B>Dynamic clustering</B>:<BR>cortical parcels are computed within<BR>consecutive time windows</HTML>');jButtonGroupCLS.add(jRadioDynamic);
        JPanelCLSType.add(jRadioDynamic);
        % MSP window
        jTextMspWindow = JTextField(num2str(OPTIONS.clustering.MSP_window));
        jTextMspWindow.setToolTipText('<HTML><B>Dynamic clustering</B>:<BR>size of the sliding window (ms)</HTML>');        
        jTextMspWindow.setPreferredSize(Dimension(TEXT_WIDTH, DEFAULT_HEIGHT));
        jTextMspWindow.setHorizontalAlignment(JTextField.RIGHT);
        JPanelCLSType.add('tab', jTextMspWindow);
        
        % Clustering : Static (RadioButton)
        JPanelCLSType.add('br', JLabel(''));
        jRadioStatic = JRadioButton('Stable in time', strcmp(OPTIONS.clustering.clusters_type,'static') );
        java_setcb(jRadioStatic, 'ActionPerformedCallback', @(h,ev)UpdatePanel());
        jRadioStatic.setToolTipText('<HTML><B>Static clustering</B>:<BR>one set of cortical parcels<BR>computed for the whole data</HTML>');        
        jButtonGroupCLS.add(jRadioStatic);
        JPanelCLSType.add(jRadioStatic); %UNCOMMENT THIS WHEN STABLE
        %CLUSTERING IS READY
        
        % Clustering : Frequency-adapted (RadioButton)
        JPanelCLSType.add('br', JLabel(''));
        jRadioFreq = JRadioButton('wavelet-adaptive', strcmp(OPTIONS.clustering.clusters_type,'wfdr') );
        java_setcb(jRadioFreq, 'ActionPerformedCallback', @(h,ev)UpdatePanel());
        jRadioFreq.setToolTipText('<HTML><B>Dynamic clustering</B>:<BR>Size of time windows are adapted<BR>to the size of time-scale boxes</HTML>');        
        jButtonGroupCLS.add(jRadioFreq);
        JPanelCLSType.add(jRadioFreq);
        
         % Separator
        JPanelCLSType.add('br', JLabel(''));
        gui_component('label', JPanelCLSType, [], ' ');
        jsep = gui_component('label', JPanelCLSType, 'br hfill', ' ');
        jsep.setBackground(java.awt.Color(.4,.4,.4));
        jsep.setOpaque(1);
        jsep.setPreferredSize(Dimension(1,1));
        gui_component('label', JPanelCLSType, 'br', ' ');
                    
        JPanelCLSType.add('br', JLabel(''));
        
        % MSP scores threshold
        JPanelCLSType.add('br', JLabel('MSP scores threshold : '));
        jButtonMSPscth = ButtonGroup();
        % Arbitrary
        JPanelCLSType.add('br', JLabel(''));
        jRadioSCRarb = JRadioButton('Arbitrary', ~strcmp(OPTIONS.clustering.MSP_scores_threshold,'fdr') );
        java_setcb(jRadioSCRarb, 'ActionPerformedCallback', @(h,ev)UpdatePanel());
        jRadioSCRarb.setToolTipText('<HTML><B>Arbitrary threshold</B>:<BR>whole brain parcellation if set to 0 ([0 1])</HTML>');        
        jButtonMSPscth.add(jRadioSCRarb);
        JPanelCLSType.add(jRadioSCRarb);
        jTextMspThresh = JTextField(num2str(OPTIONS.clustering.MSP_scores_threshold));
        jTextMspThresh.setPreferredSize(Dimension(TEXT_WIDTH, DEFAULT_HEIGHT));
        jTextMspThresh.setHorizontalAlignment(JTextField.RIGHT);
        java_setcb(jTextMspThresh, 'ActionPerformedCallback', @(h,ev)adjust_range('jTextMspThresh', [0 1]));
        JPanelCLSType.add('tab tab', jTextMspThresh);
        % FDR
        JPanelCLSType.add('br', JLabel(''));
        jRadioSCRfdr = JRadioButton('FDR method', strcmp(OPTIONS.clustering.MSP_scores_threshold,'fdr') );
        java_setcb(jRadioSCRfdr, 'ActionPerformedCallback', @(h,ev)UpdatePanel());
        jRadioSCRfdr.setToolTipText('<HTML><B>Adaptive threshold</B>:<BR>thresholds are learned from baseline<BR>using the FDR method</HTML>');        
        jButtonMSPscth.add(jRadioSCRfdr);
        JPanelCLSType.add(jRadioSCRfdr);
        
       
         % Separator
        JPanelCLSType.add('br', JLabel(''));
        gui_component('label', JPanelCLSType, [], ' ');
        jsep = gui_component('label', JPanelCLSType, 'br hfill', ' ');
        jsep.setBackground(java.awt.Color(.4,.4,.4));
        jsep.setOpaque(1);
        jsep.setPreferredSize(Dimension(1,1));
        gui_component('label', JPanelCLSType, 'br', ' ');
                    
        JPanelCLSType.add('br', JLabel(''));
        
                
        % Neighborhood order
        JPanelCLSType.add('br', JLabel(''));
        jTextNeighbor = JTextField( num2str(OPTIONS.clustering.neighborhood_order)); 
        jTextNeighbor.setPreferredSize(Dimension(TEXT_WIDTH, DEFAULT_HEIGHT));
        jTextNeighbor.setHorizontalAlignment(JTextField.RIGHT);
        jTextNeighbor.setToolTipText('<HTML><B>Neighborhood order</B>:<BR>sets maximal size of cortical parcels<BR>(initial source configuration for MEM)</HTML>');        
        JPanelCLSType.add(JLabel('Neighborhood order:'));
        JPanelCLSType.add('tab', jTextNeighbor);
        
        if ~firstCall
            jPanelNewL.add('br hfill', JPanelCLSType); 
        end
        
        % Spatial smoothing
        JPanelCLSType.add('br', JLabel(''));
        jTextSmooth = JTextField(num2str(OPTIONS.solver.spatial_smoothing));
        jTextSmooth.setPreferredSize(Dimension(TEXT_WIDTH, DEFAULT_HEIGHT));
        jTextSmooth.setHorizontalAlignment(JTextField.RIGHT);
        jTextSmooth.setToolTipText('<HTML><B>Smoothness of MEM solution</B>:<BR>spatial regularization of  the MEM<BR>(linear decay of spatial source correlations [0 1])</HTML>');        
        java_setcb(jTextSmooth, 'ActionPerformedCallback', @(h,ev)adjust_range('jTextSmooth', [0 1]));
        JPanelCLSType.add(JLabel('Spatial smoothing:'));
        JPanelCLSType.add('tab', jTextSmooth);
            
        
        % ===== GROUP ANALYSIS =====
        % Group analysis - conditional
        global GlobalData
        jCheckGRP   = JCheckBox('Multi-subjects spatial priors', 0);
        jCheckGRP.setToolTipText('<HTML><B>Warning</B>:<BR>Computations may take a lot of time</HTML>');        
        switch caller
            case 'gui'
                % Call from the GUI
                bstPanel        = bst_get('Panel', 'Protocols');
                jTree           = get(bstPanel,'sControls');
                selectedPaths   = awtinvoke(jTree.jTreeProtocols, 'getSelectionPaths()');
                SUBJ={}; DTS={};STD=[];
                for ii = 1 : numel( selectedPaths )
                    last    = awtinvoke( selectedPaths(ii), 'getLastPathComponent');
                    DTS{ii} = char(last.getFileName);
                    curS    = strrep( bst_fileparts( bst_fileparts( DTS{ii} ) ), filesep, '' );
                    SUBJ    = [SUBJ {curS}];
                    [st,is] = bst_get('Study', fullfile( bst_fileparts(DTS{ii}), 'brainstormstudy.mat' ) );
                    STD     = [STD is];
                end
            case 'process'
                % Call from the process
                inputData   =   varargin{1};
                DTS         =   {inputData.FileName};
                SUBJ        =   cellfun( @(a) strrep( bst_fileparts( bst_fileparts( a ) ), filesep, '' ), DTS, 'uni', 0 );
                [dum,STD]   =   cellfun( @(a) bst_get('Study', fullfile( bst_fileparts(a), 'brainstormstudy.mat' ) ), DTS, 'uni', 0 );
                STD         =   cell2mat( STD );
            case 'internal'
                
            otherwise
                fprintf('\n***\tBEst PANEL error\t***\n\tUnexpected number of input arguments to the panel\n\tPlease report to: latis@gmail.com\n\n');
        end
        
        if firstCall
            nsub = numel( unique(SUBJ) );
            MEMglobal.DataToProcess = DTS;
            MEMglobal.SubjToProcess = SUBJ;
            MEMglobal.StudToProcess = STD;
        else
            nsub        =   numel( unique(MEMglobal.SubjToProcess) );
        end
        
        if nsub>1
            JPanelGRP = gui_river([1,1], [0, 6, 6, 6], 'Group analysis');
            % Spatial smoothing
            JPanelGRP.add('tab', jCheckGRP);
            
            % Add 'Method' panel to main panel (jPanelNew)
            JPanelGRP.add('br', JLabel(''));
            JW = JLabel('    WARNING: very slow');
            JPanelGRP.add('tab', JW);
            
            if ~firstCall
                jPanelNewL.add('br hfill', JPanelGRP); 
            end
        end
               
        jPanelNew.add('br hfill', jPanelNewL);    
    %% ----------------------------------------------------------------- %%
     
    
    
    
    %% ---------------------- EXPERT OPTIONS PANEL --------------------- %%
    jTxtMuMet  = JTextField( num2str(OPTIONS.model.active_mean_method) );
        jTxtMuMet.setPreferredSize(Dimension(TEXT_WIDTH, DEFAULT_HEIGHT));
        jTxtMuMet.setHorizontalAlignment(JTextField.RIGHT);
        jTxtMuMet.setToolTipText('<HTML><B>Initialization of cluster k''s active mean (&mu)</B>:<BR>1 = regular minimum norm J (&mu<sub>k</sub> = mean(J<sub>k</sub>))<BR>2 = null hypothesis (&mu<sub>k</sub> = 0)<BR>3 = MSP-regularized minimum norm mJ (&mu<sub>k</sub> = mean(mJ<sub>k</sub>))<BR>4 = L-curve optimized Minimum Norm Estimate</HTML>');        
        jTxtMuMet.setEnabled(0);
    jTxtAlMet  = JTextField( num2str(OPTIONS.model.alpha_method) );
        jTxtAlMet.setPreferredSize(Dimension(TEXT_WIDTH, DEFAULT_HEIGHT));
        jTxtAlMet.setHorizontalAlignment(JTextField.RIGHT);
        jTxtAlMet.setToolTipText('<HTML><B>Initialization of cluster k''s active probability (&alpha)</B>:<BR>1 = average MSP scores (&alpha<sub>k</sub> = mean(MSP<sub>k</sub>))<BR>2 = max MSP scores (&alpha<sub>k</sub> = max(MSP<sub>k</sub>))<BR>3 = median MSP scores (&alpha<sub>k</sub> = mean(MSP<sub>k</sub>))<BR>4 = equal (&alpha = 0.5)<BR>5 = equal (&alpha = 1)</HTML>');        
        jTxtAlMet.setEnabled(0);
    jTxtAlThr  = JTextField( num2str(OPTIONS.model.alpha_threshold) );
        jTxtAlThr.setPreferredSize(Dimension(TEXT_WIDTH, DEFAULT_HEIGHT));
        jTxtAlThr.setHorizontalAlignment(JTextField.RIGHT);
        jTxtAlThr.setToolTipText('<HTML><B>Active probability threshold(&alpha)</B>:<BR>exclude clusters with low probability from solution<BR>&alpha<sub>k</sub> < threshold = 0</HTML>');        
        java_setcb(jTxtAlThr, 'ActionPerformedCallback', @(h,ev)adjust_range('jAlphaThresh', [0 1]) );
        jTxtAlThr.setEnabled(0);
    jTxtLmbd  = JTextField( num2str(OPTIONS.model.initial_lambda) );
        jTxtLmbd.setPreferredSize(Dimension(TEXT_WIDTH, DEFAULT_HEIGHT));
        jTxtLmbd.setHorizontalAlignment(JTextField.RIGHT);
        jTxtLmbd.setToolTipText('<HTML><B>Initialization of sensor weights vector (&lambda)</B>:<BR>0 = null hypothesis (&lambda = 0)<BR>1 = random</HTML>');        
        jTxtLmbd.setEnabled(0);
    jTxtActV  = JTextField( num2str(OPTIONS.solver.active_var_mult) );
        jTxtActV.setPreferredSize(Dimension(TEXT_WIDTH, DEFAULT_HEIGHT));
        jTxtActV.setHorizontalAlignment(JTextField.RIGHT);
        jTxtActV.setToolTipText('<HTML><B>Initialization of cluster k''s active variance(&Sigma<sub>1,k</sub>)</B>:<BR>enter a coefficient value ([0 1])<BR>&Sigma<sub>1,k</sub> = coeff * &mu<sub>k</sub></HTML>');        
        java_setcb(jTxtActV, 'ActionPerformedCallback', @(h,ev)adjust_range('jActiveVar', [0 1]) );
        jTxtActV.setEnabled(0);
     jTxtInactV  = JTextField( num2str(OPTIONS.solver.inactive_var_mult) );
        jTxtInactV.setPreferredSize(Dimension(TEXT_WIDTH, DEFAULT_HEIGHT));
        jTxtInactV.setHorizontalAlignment(JTextField.RIGHT);
        jTxtInactV.setToolTipText('<HTML><B>Initialization of cluster k''s inactive variance(&Sigma<sub>0,k</sub>)</B>:<BR>Not implemented yet</HTML>');            
        jTxtInactV.setEnabled(0);
    jBoxShow  = JCheckBox( 'Activate MEM display' );
        jBoxShow.setSelected( OPTIONS.optional.display );   
        jBoxShow.setEnabled(0);
    jBoxNewC  = JCheckBox( 'Recompute covariance matrix' );
        jBoxNewC.setSelected(OPTIONS.solver.NoiseCov_recompute);
        jBoxNewC.setToolTipText('<HTML><B>Noise covariance matrix</B>:<BR>The performance of the MEM is tied to<BR>a consistent estimation of this matrix<BR>(keep checked)</HTML>');            
    jBoxERD  = JCheckBox( 'Use emptyroom noise' );
        jBoxERD.setEnabled(0);
        jBoxERD.setSelected(0);
        jBoxERD.setToolTipText('<HTML><B>Empty room recordings</B>:<BR>we recommend these data for estimating<BR>the sensors noise covariance matrix<BR>This option is unlocked if any file in BST tree<BR>is labelled ''emptyroom''</HTML>');            
        java_setcb(jBoxERD, 'ActionPerformedCallback', @(h,ev)load_emptyroom_noise );
    jBoxPara  = JCheckBox( 'Matlab parallel computing' );
        jBoxPara.setSelected(OPTIONS.solver.parallel_matlab);
        jBoxPara.setEnabled(0);        
    jTxtVCOV  = JTextField( num2str(OPTIONS.solver.NoiseCov_method) );
        jTxtVCOV.setPreferredSize(Dimension(TEXT_WIDTH, DEFAULT_HEIGHT));
        jTxtVCOV.setHorizontalAlignment(JTextField.RIGHT);
        jTxtVCOV.setToolTipText('<HTML><B>Sensors noise covariance matrix</B>:<BR>0 = identity matrix<BR>1 = diagonal (same variance along diagonal)<BR>2 = diagonal<BR>3 = full<BR>4 = wavelet-based estimation<BR>(scale j=1 of the discrete wavelet transform)<BR>5 = wavelet-based + scale-adaptvive<BR>(different mat. for each scale of the signal)</HTML>');        
        java_setcb(jTxtVCOV, 'FocusLostCallback', @(h,ev)adjust_range('jVarCovar', {[1 4], [4 5], [1 5]}));
        jTxtVCOV.setEnabled(0);
    jTxtOptFn  = JTextField(OPTIONS.solver.Optim_method);
        jTxtOptFn.setPreferredSize(Dimension(TEXT_WIDTH, DEFAULT_HEIGHT));
        jTxtOptFn.setHorizontalAlignment(JTextField.RIGHT);
        jTxtOptFn.setToolTipText('<HTML><B>Optimization routine</B>:<BR>fminunc = Matlab standard unconst. optimization<BR><span style="margin-left:30px;">(optimization toolbox required)</span><BR>minFunc = Unconstrained optimization<BR><span style="margin-left:30px;">copyright Mark Schmidt, INRIA (faster)</span></HTML>');        
        jTxtOptFn.setEnabled(0);
    if any( strcmp(OPTIONS.mandatory.pipeline, {'wMEM', 'rMEM'}) )
        jTxtWAVtp  = JTextField(OPTIONS.wavelet.type);
        jTxtWAVtp.setPreferredSize(Dimension(TEXT_WIDTH, DEFAULT_HEIGHT));
        jTxtWAVtp.setHorizontalAlignment(JTextField.RIGHT);
        jTxtWAVtp.setEnabled(0);
        jTxtWAVtp.setToolTipText('<HTML><B>Wavelet type</B>:<BR>CWT = Continous wavelet transform (Morse)<BR>RDW = Discrete wavelet transform (real Daubechies)</HTML>');        
        jTxtWAVvm  = JTextField( num2str(OPTIONS.wavelet.vanish_moments) );
        jTxtWAVvm.setPreferredSize(Dimension(TEXT_WIDTH, DEFAULT_HEIGHT));
        jTxtWAVvm.setHorizontalAlignment(JTextField.RIGHT);
        jTxtWAVvm.setToolTipText('<HTML><B>Vanishing moments</B>:<BR>high polynomial order filtered out by the wavelet<BR>(compromise between frequency resolution and temporal decorrelation)</HTML>');        
        jTxtWAVvm.setEnabled(0);
        
        % ==== Wavelet processing
        jPanelWAV = gui_river([1,1], [0, 6, 6, 6], 'Wavelet processing');
        % Wavelet type
        jPanelWAV.add('p left', JLabel('Wavelet type') );
        jPanelWAV.add('tab', jTxtWAVtp);
        % Vanish
        jPanelWAV.add('p left', JLabel('Vanishing moments') );
        jPanelWAV.add('tab', jTxtWAVvm);
        
        if strcmp(OPTIONS.mandatory.pipeline, 'wMEM')
            % Shrinkage
            jTxtWAVsh  = JTextField( num2str(OPTIONS.wavelet.shrinkage) );
            jTxtWAVsh.setPreferredSize(Dimension(TEXT_WIDTH, DEFAULT_HEIGHT));
            jTxtWAVsh.setHorizontalAlignment(JTextField.RIGHT);
            jTxtWAVsh.setEnabled(0);
            jTxtWAVsh.setToolTipText('<HTML><B>DWT denoising</B>:<BR>0 = no denoising<BR>1 = soft denoising (remove low energy coeff.)</HTML>');        
            jPanelWAV.add('p left', JLabel('Coefficient shrinkage') );
            jPanelWAV.add('tab', jTxtWAVsh);            
            
        elseif strcmp(OPTIONS.mandatory.pipeline, 'rMEM')
            % Order
            jTxtWAVor  = JTextField( num2str(OPTIONS.wavelet.order) );
            jTxtWAVor.setPreferredSize(Dimension(TEXT_WIDTH, DEFAULT_HEIGHT));
            jTxtWAVor.setHorizontalAlignment(JTextField.RIGHT);
            jTxtWAVor.setEnabled(0);
            jPanelWAV.add('p left', JLabel('Wavelet order') );
            jPanelWAV.add('tab', jTxtWAVor);
            % Levels
            jTxtWAVlv  = JTextField( num2str(OPTIONS.wavelet.nb_levels) );
            jTxtWAVlv.setPreferredSize(Dimension(TEXT_WIDTH, DEFAULT_HEIGHT));
            jTxtWAVlv.setHorizontalAlignment(JTextField.RIGHT);
            jTxtWAVlv.setEnabled(0);
            jPanelWAV.add('p left', JLabel('Decomposition levels') );
            jPanelWAV.add('tab', jTxtWAVlv);
            
            % ==== Ridges
            jPanelRDG = gui_river([1,1], [0, 6, 6, 6], 'Ridge processing');
            % SC NRJ
            jTxtRsct  = JTextField( num2str(OPTIONS.ridges.scalo_threshold) );
            jTxtRsct.setPreferredSize(Dimension(TEXT_WIDTH, DEFAULT_HEIGHT));
            jTxtRsct.setHorizontalAlignment(JTextField.RIGHT);
            jTxtRsct.setToolTipText('<HTML><B>Scalogram threshold</B>:<BR>Keep local maxima up to threshod * total energy of the CWT</HTML>');        
            jTxtRsct.setEnabled(0);
            jPanelRDG.add('p left', JLabel('Scalogram energy threshold') );
            jPanelRDG.add('tab', jTxtRsct);
            % BSL cumul thr
            jTxtRbct  = JTextField( num2str(OPTIONS.ridges.energy_threshold) );
            jTxtRbct.setPreferredSize(Dimension(TEXT_WIDTH, DEFAULT_HEIGHT));
            jTxtRbct.setHorizontalAlignment(JTextField.RIGHT);
            jTxtRbct.setToolTipText('<HTML><B>Baseline cumulative threshold</B>:<BR>Adaptive cutoff for selecting signifciant ridges<BR>Learned from the distribution of ridge strengths in the baseline<BR>Cutoff is the percentile of that distribution indicated by threshold</HTML>');        
            jTxtRbct.setEnabled(0);
            jPanelRDG.add('p left', JLabel('Baseline cumulative threshold') );
            jPanelRDG.add('tab', jTxtRbct);
            % RDG str thr
            jTxtRst  = JTextField( num2str(OPTIONS.ridges.strength_threshold) );
            jTxtRst.setPreferredSize(Dimension(TEXT_WIDTH, DEFAULT_HEIGHT));
            jTxtRst.setHorizontalAlignment(JTextField.RIGHT);
            jTxtRst.setToolTipText('<HTML><B>Ridge strength threshold</B>:<BR>double = arbitrary threshold ([0 1])<BR>blank = adaptive threshold (recommanded)</HTML>');        
            jTxtRst.setEnabled(0);
            jPanelRDG.add('p left', JLabel('Ridge strength threshold') );
            jPanelRDG.add('tab', jTxtRst);            
            % Cycles
            jTxtRmc  = JTextField( num2str(OPTIONS.ridges.cycles_in_window) );
            jTxtRmc.setPreferredSize(Dimension(TEXT_WIDTH, DEFAULT_HEIGHT));
            jTxtRmc.setHorizontalAlignment(JTextField.RIGHT);
            jTxtRmc.setToolTipText('<HTML><B>Number of cycles within MSP</B><BR>only available for wavelet-adaptive clustering</HTML>');        
            jTxtRmc.setEnabled(0);
            jPanelRDG.add('p left', JLabel('Ridge minimum cycles') );
            jPanelRDG.add('tab', jTxtRmc);

        end
      
    end
            
    jPanelNewR = gui_river();

    % Model priors
    jPanelModP = gui_river([1,1], [0, 6, 6, 6], 'Model priors');
    % mu
    jPanelModP.add('p left', JLabel('Active mean intialization') );
    jPanelModP.add('tab tab', jTxtMuMet);
    % alpha m
    jPanelModP.add('p left', JLabel('Active probability intialization') );
    jPanelModP.add('tab', jTxtAlMet);
    % alpha t
    jPanelModP.add('p left', JLabel('Active probability threshold') );
    jPanelModP.add('tab', jTxtAlThr);
    % lambda
    jPanelModP.add('p left', JLabel('Lambda') );
    jPanelModP.add('tab', jTxtLmbd);
    % Active var
    jPanelModP.add('p left', JLabel('Active variance coeff.') );
    jPanelModP.add('tab', jTxtActV);
    % Inactive var
    jPanelModP.add('p left', JLabel('Inactive variance coeff.') );
    jPanelModP.add('tab', jTxtInactV);
    % Add priors to panel
    jPanelNewR.add('br hfill', jPanelModP);

    % Solver
    jPanelSensC = gui_river([1,1], [0, 6, 6, 6], 'Solver options');
    % Optimization routine
    jPanelSensC.add('p left', JLabel('Optimization routine') );
    jPanelSensC.add('tab tab', jTxtOptFn);
     
    
    % Display
    jPanelSensC.add('p left', jBoxShow);
    % Parallel computing
    jPanelSensC.add('p left', jBoxPara);
    % Separator
    jPanelSensC.add('br', JLabel(''));
    gui_component('label', JPanelparam, [], ' ');
    jsep = gui_component('label', jPanelSensC, 'br hfill', ' ');
    jsep.setBackground(java.awt.Color(.4,.4,.4));
    jsep.setOpaque(1);
    jsep.setPreferredSize(Dimension(1,1));
    gui_component('label', jPanelSensC, 'br', '');
    % Compute new matrix?
    jPanelSensC.add('p left', jBoxNewC);
    % Use emptyroom noise?
    jPanelSensC.add('p left', jBoxERD);
    % Matrix type
    jPanelSensC.add('p left', JLabel('Covariance matrix type') );
    jPanelSensC.add('tab tab', jTxtVCOV);
    % Add priors to panel
    jPanelNewR.add('br hfill', jPanelSensC);

    if strcmp(OPTIONS.mandatory.pipeline, 'wMEM')
        % Add priors to panel
        jPanelNewR.add('br hfill', jPanelWAV);
    elseif strcmp(OPTIONS.mandatory.pipeline, 'rMEM')            
        % Add priors to panel
        jPanelNewR.add('br hfill', jPanelWAV);
        jPanelNewR.add('br hfill', jPanelRDG);
    end
        
    if ~firstCall
        jPanelNew.add('right', jPanelNewR);
    end

    %% ----------------------------------------------------------------- %%

    % ===== VALIDATION BUTTONS =====
    if OPTIONS.automatic.MEMexpert
        JButEXP = gui_component('button', jPanelNew, 'br center', 'Normal', [], [], @SwitchExpertMEM, []);
    else
        JButEXP = gui_component('button', jPanelNew, 'br center', 'Expert', [], [], @SwitchExpertMEM, []);
    end
        
    if ~any([jMEMdef.isSelected() jMEMw.isSelected() jMEMr.isSelected()])
        JButEXP.setEnabled(0);
        %JPanelparam.setVisible(0);
        JPanelCLSType.setVisible(0);
        jPanelModP.setVisible(0);
        jPanelSensC.setVisible(0);
        if exist('JPanelGRP', 'var'); JPanelGRP.setVisible(0); end;
        if exist('JPanelnwav', 'var'); JPanelnwav.setVisible(0); end;
        if exist('jPanelWAV', 'var'); jPanelWAV.setVisible(0); end;
        if exist('jPanelRDG', 'var'); jPanelRDG.setVisible(0); end;
    end

    gui_component('button', jPanelNew, [], 'Cancel', [], [], @ButtonCancel_Callback, []);
    JButOK = gui_component('button', jPanelNew, [], 'OK', [], [], @ButtonOk_Callback, []);
    JButOK.setEnabled(0);
    
    % ===== PANEL CREATION =====
    % Return a mutex to wait for panel close
    bst_mutex('create', panelName);
    % Controls list
    ctrl = struct('jMEMdef',              jMEMdef, ...
                  'jMEMw',                jMEMw, ...
                  'jMEMr',                jMEMr, ...
                  'jCLSd',                jRadioDynamic, ...
                  'jCLSs',                jRadioStatic, ...
                  'jCLSf',                jRadioFreq, ...
                  'jTextSmooth',          jTextSmooth, ...
                  'jTextNeighbor',        jTextNeighbor, ...
                  'jTextMspWindow',       jTextMspWindow, ...
                  'jTextMspThresh',       jTextMspThresh, ...
                  'jTextTimeStart',       jTextTimeStart, ...
                  'jTextTimeStop',        jTextTimeStop,...
                  'jTextBSLStart',        jTextBSLStart, ...
                  'jTextBSLStop',         jTextBSLStop, ...
                  'jRadioSCRarb',         jRadioSCRarb, ...
                  'jRadioSCRfdr',         jRadioSCRfdr, ...
                  'jButtonBSL',           jbslfl, ...
                  'jTextBSL',             jBSLflnm, ...
                  'jCheckGRP',            jCheckGRP, ...
                  'jPanelTop',            jPanelNew, ...
                  'jMuMethod',            jTxtMuMet, ... 
                  'jAlphaMethod',         jTxtAlMet, ...
                  'jAlphaThresh',         jTxtAlThr, ...
                  'jLambda',              jTxtLmbd, ...
                  'jActiveVar',           jTxtActV, ...
                  'jInactiveVar',         jTxtInactV, ...
                  'jVarCovar',            jTxtVCOV, ...
                  'jOptimFN',             jTxtOptFn, ...
                  'jNewCOV',              jBoxNewC, ...
                  'jParallel',            jBoxPara, ...
                  'jButEXP',              JButEXP, ...
                  'jradwit',              jRadioBslWithin, ...
                  'jraddef',              jRadioBslDefault, ...
                  'jradimp',              jRadioBslImport, ...
                  'jButOk',               JButOK, ...
                  'jBoxShow',             jBoxShow, ...
                  'jBoxERD',              jBoxERD, ...
                  'jTXTver',              jTXTver, ...
                  'jTXTupd',              jTXTupd);              
      
    if any( strcmp(OPTIONS.mandatory.pipeline, {'wMEM', 'rMEM'}) )
        ctrl.jWavType           =   jTxtWAVtp;
        ctrl.jWavVanish         =   jTxtWAVvm;
        
    	if strcmp(OPTIONS.mandatory.pipeline, 'wMEM')
            ctrl.jWavShrinkage	=   jTxtWAVsh;
            ctrl.jWavScales     =   jBoxWAVsc;
                                    
        elseif strcmp(OPTIONS.mandatory.pipeline, 'rMEM')
            ctrl.jWavOrder      =   jTxtWAVor;
            ctrl.jWavLevels     =   jTxtWAVlv;
            ctrl.jRDGscaloth    =   jTxtRsct;
            ctrl.jRDGnrjth      =   jTxtRbct;
            ctrl.jRDGstrength   =   jTxtRst;
            ctrl.jRDGrangeS     =   jTxtRfrs;
            ctrl.jRDGmindur     =   jTxtRmd;
            ctrl.jRDGmincycles	=   jTxtRmc;
        end
        
    end
    
    % Create the BstPanel object that is returned by the function
    % => constructor BstPanel(jHandle, panelName, sControls)
    bstPanelNew = BstPanel(panelName, jPanelNew, ctrl);
    
%% =================================================================================
%  === INTERNAL CALLBACKS ==========================================================
%  =================================================================================
%% ===== CANCEL BUTTON =====
    function ButtonCancel_Callback(hObject, event)
        % Close panel without saving (release mutex automatically)
        gui_hide(panelName);
    end

%% ===== OK BUTTON =====
    function ButtonOk_Callback(varargin)       
        % Release mutex and keep the panel opened
        bst_mutex('release', panelName);
        be_print_best(OPTIONS);
    end

    %% ===== SWITCH EXPERT MODE =====
    function SwitchExpertMEM(varargin)
        OPTIONS     = panel_brainentropy('GetPanelContents');
        OPTIONS     = OPTIONS.MEMpaneloptions;
        ctrl        = bst_get('PanelControls', 'InverseOptionsMEM');
        
        % Toggle expert mode
        choices = {'Normal', 'Expert'};
        ExpertMEM   = OPTIONS.automatic.MEMexpert;
        ctrl.jButEXP.setText( choices{ExpertMEM+1} );
        
        UpdatePanel;        
    end   

    %% ===== SWITCH PIPELINE =====
    function SwitchPipeline(varargin)
        bst_mutex('release', 'InverseOptionsMEM');
        % Get old panel
        [bstPanelOld, iPanel] = bst_get('Panel', 'InverseOptionsMEM');
        container   = get(bstPanelOld, 'container');
        jFrame      = container.handle{1};
        
        ctrl        = bst_get('PanelControls', 'InverseOptionsMEM');        
        % if first click, get default values
        if MEMglobal.first_instance
            OPTIONS =   be_main();
            chx     =   {'cMEM', 'wMEM', 'rMEM'};
            OPTIONS.mandatory.pipeline      =   chx{ find([ctrl.jMEMdef.isSelected() ctrl.jMEMw.isSelected() ctrl.jMEMr.isSelected()]) };
            OPTIONS.automatic.version       =   char(ctrl.jTXTver.getText());
            OPTIONS.automatic.last_update   =   char(ctrl.jTXTupd.getText());
        else
            OPTIONS     = panel_brainentropy('GetPanelContents');
            OPTIONS     = OPTIONS.MEMpaneloptions;
        end
        
        % Get new options
        MEMoptions          =   struct('mandatory', struct('pipeline', OPTIONS.mandatory.pipeline), 'automatic', struct('stand_alone', 1) ); 
        if any( strcmp(OPTIONS.mandatory.pipeline, {'wMEM', 'rMEM'}) )
            nOPT                =   be_main( [], MEMoptions );
            OPTIONS             =   be_struct_copy_fields(nOPT, OPTIONS, []);
            if strcmp(OPTIONS.mandatory.pipeline, 'rMEM')
                OPTIONS.ridges  =   nOPT.ridges;
                if isfield(MEMglobal, 'selected_scale_index'); MEMglobal = rmfield(MEMglobal, 'selected_scale_index'); end
            else
                if isfield(MEMglobal, 'selected_freqs_index'); MEMglobal = rmfield(MEMglobal, 'selected_freqs_index'); end
            end
        elseif strcmp( OPTIONS.mandatory.pipeline, 'cMEM' )
            if isfield(MEMglobal, 'selected_scale_index'); MEMglobal = rmfield(MEMglobal, 'selected_scale_index'); end
            if isfield(MEMglobal, 'selected_freqs_index'); MEMglobal = rmfield(MEMglobal, 'selected_freqs_index'); end
        end
        
        % Create new panel contents
        bstPanelNew = panel_brainentropy('CreatePanel', OPTIONS, 'internal');
        sControls   = get(bstPanelNew, 'sControls');
        
        % Replace old main panel with new one
        oldC        = get(bstPanelOld, 'sControls');
        sControls.jraddef.setSelected( oldC.jraddef.isSelected() );
        sControls.jradwit.setSelected( oldC.jradwit.isSelected() );
        sControls.jradimp.setSelected( oldC.jradimp.isSelected() );
        jFrame.getContentPane().removeAll();
        jFrame.getContentPane().add(sControls.jPanelTop);
        jFrame.pack();
        
        % Register new components
        bstPanelOld = set(bstPanelOld, 'sControls', sControls);
        GlobalData.Program.GUI.panels(iPanel) = bstPanelOld;
        UpdatePanel;
        bst_mutex('waitfor', 'InverseOptionsMEM');
        
    end

end



%% =================================================================================
%  === EXTERNAL CALLBACKS ==========================================================
%  =================================================================================   
%% ===== UPDATE PANEL =====
function UpdatePanel(hObject, event)
    ctrl = bst_get('PanelControls', 'InverseOptionsMEM');
    OPTIONS     = panel_brainentropy('GetPanelContents');
	OPTIONS     = OPTIONS.MEMpaneloptions;
        
    ctrl.jTextMspWindow.setEnabled(1);
    ctrl.jTextMspThresh.setEnabled(1);
    ctrl.jRadioSCRarb.setEnabled(1);
									
    ctrl.jCLSd.setEnabled(1);
    ctrl.jCLSs.setEnabled(1);
    ctrl.jBoxERD.setEnabled(0);
    
    % ADVANCED
    if ctrl.jMEMdef.isSelected()
        ctrl.jCLSf.setEnabled(0);
        ctrl.jMEMdef.setSelected(1)
        if ctrl.jCLSf.isSelected()
            ctrl.jCLSd.setSelected(1);
            ctrl.jCLSd.setEnabled(1);
        end
    else
        ctrl.jCLSf.setEnabled(1);
        ctrl.jCLSs.setEnabled(0);   
    end

    if ctrl.jMEMw.isSelected()
        ctrl.jCLSd.setEnabled(0);
        ctrl.jCLSf.setSelected(1);
        %ctrl.jRadioSCRarb.setEnabled(0);
    end 

    if ~ctrl.jCLSd.isSelected() 
        ctrl.jTextMspWindow.setEnabled(0);
    end

    %if ctrl.jCLSs.isSelected()
        %ctrl.jRadioSCRarb.setEnabled(1);
        %ctrl.jRadioSCRarb.setSelected(0);
        %ctrl.jTextMspThresh.setText('0');
    %end

    if ~ctrl.jRadioSCRarb.isSelected()
        ctrl.jTextMspThresh.setEnabled(0);								  
        ctrl.jTextMspThresh.setText('fdr')
	else
		ctrl.jTextMspThresh.setText('0')
    end

    if feature('NumCores')<2
        ctrl.jParallel.setEnabled(0);
        ctrl.jParallel.setSelected(0);
    end
    
    % look for default baseline
    [bsl, dum, ERD] = look_for_default(ctrl);
    if isempty(bsl)
        ctrl.jraddef.setEnabled(0);
    else
        load_default_baseline;
        if ~ctrl.jradwit.isSelected() && ~ctrl.jradimp.isSelected()
            ctrl.jraddef.setSelected(1);
        end
    end
        
    % emptyroom
    if ~isempty(ERD)
        ctrl.jBoxERD.setEnabled(1);
    end
    
    % refresh data time definition
    check_time('time', '', '', 'set_TF');   
    
    % Conditions for enabling OK button
    COND1   =   any([ctrl.jraddef.isSelected() ctrl.jradwit.isSelected() ctrl.jradimp.isSelected()]); % ONE METHOD FOR BASELINE IS SELECTED
    COND2   =   1; if ctrl.jMEMw.isSelected() && strcmp( char( ctrl.jWavScales.getSelectedItem() ), 'sig. too short (min 128 samples)'); COND2=0;end % AT LEAST 128 samples for wMEM
    COND3   =   1; if ctrl.jMEMr.isSelected() && strcmp( char( ctrl.jRDGrangeS.getSelectedItem() ), 'sig. too short (min 128 samples)'); COND3=0;end % AT LEAST 128 samples for rMEM
    
    if COND1 && COND2 && COND3
        ctrl.jButOk.setEnabled(1);
    end
    
    % Expert
    ctrl.jButEXP.setEnabled(1);
    if ~OPTIONS.automatic.MEMexpert
        expVal = 0;
        ctrl.jButEXP.setText('Expert');
    else
        expVal = 1;
        ctrl.jButEXP.setText('Normal');
    end
    
    ctrl.jMuMethod.setEnabled(expVal);
    ctrl.jAlphaMethod.setEnabled(expVal);
    ctrl.jAlphaThresh.setEnabled(expVal);
    ctrl.jLambda.setEnabled(expVal);
    ctrl.jActiveVar.setEnabled(expVal);
    ctrl.jInactiveVar.setEnabled(expVal);
    ctrl.jBoxShow.setEnabled(expVal);
    ctrl.jNewCOV.setEnabled(expVal);
    ctrl.jParallel.setEnabled(expVal);
    ctrl.jVarCovar.setEnabled(expVal);
    ctrl.jOptimFN.setEnabled(expVal);

    if any( strcmp(OPTIONS.mandatory.pipeline, {'wMEM', 'rMEM'}) )
        ctrl.jWavType.setEnabled(expVal);
        ctrl.jWavVanish.setEnabled(expVal);

        if strcmp(OPTIONS.mandatory.pipeline, 'wMEM')
            ctrl.jWavShrinkage.setEnabled(expVal);

        elseif strcmp(OPTIONS.mandatory.pipeline, 'rMEM')
            ctrl.jWavOrder.setEnabled(expVal);
            ctrl.jWavLevels.setEnabled(expVal);
            ctrl.jRDGscaloth.setEnabled(expVal);
            ctrl.jRDGnrjth.setEnabled(expVal);
            ctrl.jRDGstrength.setEnabled(expVal);
            ctrl.jRDGmincycles.setEnabled(expVal);
        end
    end                               
    
end
    
%% ===== GET PANEL CONTENTS =====
function s = GetPanelContents(varargin) %#ok<DEFNU>
    % Get panel controls
    ctrl = bst_get('PanelControls', 'InverseOptionsMEM');
    MEMpaneloptions.InverseMethod = 'MEM';
    MEMpaneloptions.automatic.MEMexpert  =   strcmp( char(ctrl.jButEXP.getText()),'Normal' );                    
    
    % Get all the text options
    MEMpaneloptions.clustering.neighborhood_order     = str2double(char(ctrl.jTextNeighbor.getText()));
    MEMpaneloptions.clustering.MSP_window             = str2double(char(ctrl.jTextMspWindow.getText()));
    MEMpaneloptions.optional.TimeSegment              = [str2double(char(ctrl.jTextTimeStart.getText())) ...
                                                        str2double(char(ctrl.jTextTimeStop.getText()))];
    MEMpaneloptions.optional.groupAnalysis            = ctrl.jCheckGRP.isSelected(); 
    MEMpaneloptions.optional.TimeSegment(isnan(MEMpaneloptions.optional.TimeSegment) ) = [];
    
    % Get MEM method
    choices = {'cMEM', 'wMEM', 'rMEM'};
    selected = [ctrl.jMEMdef.isSelected() ctrl.jMEMw.isSelected() ctrl.jMEMr.isSelected()];
    MEMpaneloptions.mandatory.pipeline      =   choices{ selected };
    MEMpaneloptions.automatic.version       =   char( ctrl.jTXTver.getText() ); 
    MEMpaneloptions.automatic.last_update   =   char( ctrl.jTXTupd.getText() ); 
    
    % Get clustering method
    choices = {'blockwise', 'static', 'wfdr'};
    selected = [ctrl.jCLSd.isSelected() ctrl.jCLSs.isSelected() ctrl.jCLSf.isSelected()];
    MEMpaneloptions.clustering.clusters_type = choices{ selected };
    
    % Get MSP thresholding method
    MEMpaneloptions.clustering.MSP_scores_threshold = 'fdr';
    if ctrl.jRadioSCRarb.isSelected()
        MEMpaneloptions.clustering.MSP_scores_threshold = str2double(char(ctrl.jTextMspThresh.getText()));
        if isnan(MEMpaneloptions.clustering.MSP_scores_threshold)
            %fprintf('panel_brainentropy:\tWrong value for MSP scores threshold. Set to 0\n')
            ctrl.jTextMspThresh.setText('0');
            %ctrl.jRadioSCRarb.setSelected(0)
            %ctrl.jRadioSCRfdr.setSelected(1)
        end
    end
    
    % Get baseline
    global MEMglobal
								   
																				
    if ctrl.jradwit.isSelected()
        MEMpaneloptions.optional.Baseline = [];
        MEMpaneloptions.optional.BaselineHistory{1} = 'within';
    elseif ctrl.jraddef.isSelected() || ctrl.jradimp.isSelected()
        MEMpaneloptions.optional.Baseline           = MEMglobal.Baseline;
        MEMpaneloptions.optional.BaselineTime       = MEMglobal.BaselineTime;
        MEMpaneloptions.optional.BaselineChannels   = MEMglobal.BaselineChannels;
        MEMpaneloptions.optional.BaselineHistory    = MEMglobal.BaselineHistory;
    end
    % Get emptyroom
    if ctrl.jBoxERD.isSelected()
        MEMpaneloptions.optional.EmptyRoom_data     = MEMglobal.EmptyRoomData;
        MEMpaneloptions.optional.EmptyRoom_channels = MEMglobal.EmptyRoomChannels;  
    end
    MEMpaneloptions.optional.display            = ctrl.jBoxShow.isSelected();
    MEMpaneloptions.optional.BaselineSegment    = [str2double(char(ctrl.jTextBSLStart.getText())) ...
        str2double(char(ctrl.jTextBSLStop.getText()))];
    if any(isnan( MEMpaneloptions.optional.BaselineSegment ) )
        MEMpaneloptions.optional.BaselineSegment = [];
    end
    tmpDir = bst_get('BrainstormTmpDir');
    delete( fullfile(tmpDir, '*.*') );
    
    % Advanced options
    MEMpaneloptions.model.active_mean_method    =   str2double( ctrl.jMuMethod.getText() );
    MEMpaneloptions.model.alpha_method          =   str2double( ctrl.jAlphaMethod.getText() );
    MEMpaneloptions.model.alpha_threshold      	=   str2double( ctrl.jAlphaThresh.getText() );
    MEMpaneloptions.model.initial_lambda        =   str2double( ctrl.jLambda.getText() );
    
    MEMpaneloptions.solver.spatial_smoothing    =   str2double(char(ctrl.jTextSmooth.getText()));
    MEMpaneloptions.solver.active_var_mult      =   str2double( ctrl.jActiveVar.getText() );
    MEMpaneloptions.solver.inactive_var_mult  	=   str2double( ctrl.jInactiveVar.getText() );
    MEMpaneloptions.solver.NoiseCov_method    	=   str2double( ctrl.jVarCovar.getText() );
    MEMpaneloptions.solver.Optim_method       	=   char( ctrl.jOptimFN.getText() );
    MEMpaneloptions.solver.parallel_matlab      =   double( ctrl.jParallel.isSelected() );
    MEMpaneloptions.solver.NoiseCov_recompute   =   double( ctrl.jNewCOV.isSelected() );
    
    if any( strcmp(MEMpaneloptions.mandatory.pipeline, {'wMEM','rMEM'}) ) && isfield(ctrl, 'jWavType')
        MEMpaneloptions.wavelet.type            =   char( ctrl.jWavType.getText() );
        MEMpaneloptions.wavelet.vanish_moments 	=   str2double( ctrl.jWavVanish.getText() );
    
        if strcmp(MEMpaneloptions.mandatory.pipeline, 'wMEM') && isfield(ctrl, 'jWavShrinkage')
            MEMpaneloptions.wavelet.shrinkage   =   str2double( ctrl.jWavShrinkage.getText() );
            
            % process scales
            SCL = lower( char( ctrl.jWavScales.getSelectedItem() ) );
            if any( strcmpi( SCL, {'all','0'} ) )||isempty(SCL)
                nSC = ctrl.jWavScales.getItemCount();
                MEMpaneloptions.wavelet.selected_scales = 1 : nSC-2;                
            
            elseif strcmpi( SCL, 'not enough samples' )
                MEMpaneloptions.wavelet.selected_scales = []; 
                
            else                
                id1 = find(SCL=='(');
                id2 = find(SCL==')');
                for ii = 1: numel(id1)
                    SCL(id1(ii):id2(ii)) = '';
                end
                MEMpaneloptions.wavelet.selected_scales = eval(['[' SCL ']']);
            end
            
        elseif isfield(ctrl, 'jWavOrder')
            MEMpaneloptions.wavelet.order     	=   str2double( ctrl.jWavOrder.getText() );
            MEMpaneloptions.wavelet.nb_levels  	=   str2double( ctrl.jWavLevels.getText() );
    
            MEMpaneloptions.ridges.scalo_threshold       =   str2double( ctrl.jRDGscaloth.getText() );
            MEMpaneloptions.ridges.energy_threshold      =   str2double( ctrl.jRDGnrjth.getText() );
            MEMpaneloptions.ridges.strength_threshold    =   str2double( ctrl.jRDGstrength.getText() );
            MEMpaneloptions.ridges.min_duration          =   str2double( ctrl.jRDGmindur.getText() );
            MEMpaneloptions.ridges.cycles_in_window    	 =   str2double( ctrl.jRDGmincycles.getText() );
            
            % process frq range
            rng.gamma = [30 100];
            rng.beta  = [13 29];
            rng.alpha = [8 12];
            rng.delta = [4 7];
            rng.theta = [1 3];
            RNG = strrep( lower(strtrim( char( ctrl.jRDGrangeS.getSelectedItem() ) ) ), '-', ' ' );
            
            if strcmpi( RNG, 'all') || isempty(RNG)
                MEMpaneloptions.ridges.frequency_range      =   [1 99999];
                
            elseif strcmpi( RNG, 'not enough samples')
                MEMpaneloptions.ridges.frequency_range      =   [];
                
            else
                RNG = strrep(RNG, ' ', ''';''');
                RNG = eval(['{''' RNG '''}']);
                miF = [];maF = [];
                for ii = 1 : numel(RNG)
                    if ~isnan( str2double(RNG{ii}) )
                        miF = [miF str2double(RNG{ii})];
                        maF = [maF str2double(RNG{ii})];
                    elseif any( strcmp(RNG{ii}, {'gamma', 'beta', 'alpha', 'theta', 'delta'}) )
                        miF = [miF rng.(RNG{ii})(1)];
                        maF = [maF rng.(RNG{ii})(2)];
                    end
                end
                MEMpaneloptions.ridges.frequency_range      =   [min(miF) max(maF)];
                
                if MEMpaneloptions.ridges.frequency_range(1)<MEMglobal.freqs_analyzed(1)
                    MEMpaneloptions.ridges.frequency_range(1)   =   MEMglobal.freqs_analyzed(1);
                    fprintf('panel_brainentropy:\tmin. ridge frequency was out of range\n\t\t\tset to: %f\n', MEMglobal.freqs_analyzed(1));
                elseif MEMpaneloptions.ridges.frequency_range(1)>MEMglobal.freqs_analyzed(end)
                    MEMpaneloptions.ridges.frequency_range(1)   =   MEMglobal.freqs_analyzed(1);
                    fprintf('panel_brainentropy:\tmin. ridge frequency was out of range\n\t\t\tset to: %f\n', MEMglobal.freqs_analyzed(1));
                end
                if MEMpaneloptions.ridges.frequency_range(2)>MEMglobal.freqs_analyzed(end)
                    MEMpaneloptions.ridges.frequency_range(2)   =   MEMglobal.freqs_analyzed(end);
                    fprintf('panel_brainentropy:\tmin. ridge frequency was out of range\n\t\tset to: %f\n', MEMglobal.freqs_analyzed(end));
                elseif MEMpaneloptions.ridges.frequency_range(2)<MEMpaneloptions.ridges.frequency_range(1)
                    MEMpaneloptions.ridges.frequency_range(2)   =   MEMglobal.freqs_analyzed(end);
                    fprintf('panel_brainentropy:\tmin. ridge frequency was invalid\n\t\tset to: %f\n', MEMglobal.freqs_analyzed(end));
                end

            end
        end
    end
    
    clear global BSLinfo
    s.MEMpaneloptions = MEMpaneloptions;
    
end

function check_time(varargin)

% Check time limits
global MEMglobal
iP  = bst_get('ProtocolInfo');
iS  = MEMglobal.DataToProcess;

% Checks input 
ctrl    = bst_get('PanelControls', 'InverseOptionsMEM');
Tm = {};
for ii = 1 : numel(iS)
    load( fullfile(iP.STUDIES, iS{ii}), 'Time' );
    Tm{ii} = Time;
end
sf = cellfun(@(a) round(1/diff(a([1 2]))), Tm, 'uni', false);
St = cellfun(@(a,b) round(a(1)*b), Tm, sf, 'uni', false); St = max( [St{:}] );
Nd = cellfun(@(a,b) round(a(end)*b), Tm, sf, 'uni', false); Nd = min( [Nd{:}] );

if St > Nd
    ctrl.jTextTimeStart.setEnabled(0);
    ctrl.jTextTimeStop.setEnabled(0);

else
    Time = (St : Nd)/max([sf{:}]);

    % process input arguments
    switch varargin{1}
        case 'time'
            hndlst = ctrl.jTextTimeStart;
            hndlnd = ctrl.jTextTimeStop;

        case 'bsl'
            hndlst = ctrl.jTextBSLStart;
            hndlnd = ctrl.jTextBSLStop;
            
            switch varargin{2}
                case ''
                    if isfield(MEMglobal, 'BaselineTime') 
                        Time = MEMglobal.BaselineTime;
                    end
                case {'default', 'import'}
                    Time = MEMglobal.BaselineTime;   
            end
    
    end

    switch varargin{3}
        case 'true'
            hndlst.setText('-9999')
            hndlnd.setText('9999')
    end

    ST  = str2double( char( hndlst.getText()) ); 
    ND  = str2double( char( hndlnd.getText()) ); 

    if isnan(ST), ST = Time(1); else ST = Time( be_closest(ST,Time) ); end
    if isnan(ND), ND = Time(end); else ND = Time( be_closest(ND,Time) ); end

    if ST> min([ND Time(end)]) 
        ST=min([ND Time(end)]);
    end
    if ND< max([ST Time(1)])
        ND=max([ST Time(1)]);
    end

    hndlst.setText( num2str( max( ST, Time(1) ) ) );
    hndlnd.setText( num2str( min( ND, Time(end) ) ) );

    if numel(varargin)==4 
        if strcmp(varargin{4}, 'checkOK')
            ctrl.jButOk.setEnabled(1);
        elseif strcmp(varargin{4}, 'set_TF')
            if ctrl.jMEMw.isSelected()
                set_scales(Time);
            elseif ctrl.jMEMr.isSelected()
                set_freqs(Time);
            end           
        end
    end
end


end

function [TXT, found, iE] = look_for_default(ctrl)

global MEMglobal

ST = unique( MEMglobal.StudToProcess );
iE = [];
if numel(ST) == 0 | numel(ST)>1
    TXT = '';
    found = 0;
else
    ST = bst_get('Study', ST);
    DT = cellfun( @(a) ~isempty(a), strfind({ST.Data.Comment}, 'baseline'), 'uni', false );
    ER = cellfun( @(a) ~isempty(a), strfind({ST.Data.Comment}, 'emptyroom'), 'uni', false );
    iD = find( cell2mat(DT) );
    iE = find( cell2mat(ER) );
    
    if numel(iD) == 0
        found = 0;
        TXT   = '';
    elseif numel(iD) == 1
        TXT = ST.Data(iD).Comment;
        found = ST.Data(iD).FileName;
    else
        disp('MEM : more than one baseline found in workspace.')
        disp('MEM : first file selected')
        TXT = ST.Data(iD(1)).Comment;
        found = ST.Data(iD(1)).FileName;
    end    
end

MEMglobal.BSLinfo.comment   = TXT;
MEMglobal.BSLinfo.file      = found;

if numel(iE)
    % Found one empty room data in study
    MEMglobal.ERDinfo.file      =   {ST.Data(iE).FileName};
    MEMglobal.ERDinfo.comment   =   ST.Data(iE).Comment;
    MEMglobal.ERDinfo.found     =   numel(iE);

else
    if numel(ST) == 1
        % Check if there are ER data in subject
        [STDs]      =   bst_get('StudyWithSubject', ST.BrainStormSubject);
        ALLdforS    =   cat(2, STDs.Data);
        iE          =   cellfun(@(a) ~isempty(strfind(lower(a), 'emptyroom')), {ALLdforS.Comment}, 'uni', 0);
        iE          =   find( cell2mat(iE) );
    end

    if ~isempty(iE)
        MEMglobal.ERDinfo.comment   = ALLdforS( iE(1) ).Comment;         
        MEMglobal.ERDinfo.file      = {ALLdforS( iE(1) ).FileName};
        MEMglobal.ERDinfo.found     = numel(iE);
        
    else
        % Check if there is a ER subject
        ALLsub  =   bst_get('ProtocolSubjects');
        iE      =   cellfun(@(a) ~isempty(strfind(lower(a), 'emptyroom')), {ALLsub.Subject.Name}, 'uni', 0);
        iE      =   find( cell2mat( iE ) );
        
        if ~isempty(iE)
            % found empty room subject
            DTforS  =   bst_get('StudyWithSubject', ALLsub.Subject(iE(1)).FileName); 
            MEMglobal.ERDinfo.comment   = DTforS(1).Comment;         
            MEMglobal.ERDinfo.file      = {DTforS(1).FileName};
            MEMglobal.ERDinfo.found     = numel(DTforS);
        end
        
    end
    
end

end

function import_baseline(hObject, event)

global MEMglobal

ctrl = bst_get('PanelControls', 'InverseOptionsMEM');

DefaultFormats = bst_get('DefaultFormats');
iP  = bst_get('ProtocolInfo');  
[Lst, Frmt]   = java_getfile( 'open', ...
        'Import EEG/MEG recordings...', ...       % Window title
        iP.STUDIES, ...                           % default directory
        'single', 'files_and_dirs', ...           % Selection mode
        {{'.*'},                 'MEG/EEG: 4D-Neuroimaging/BTi (*.*)',   '4D'; ...
         {'_data'},              'MEG/EEG: Brainstorm (*data*.mat)',     'BST-MAT'; ...
         {'.meg4','.res4'},      'MEG/EEG: CTF (*.ds;*.meg4;*.res4)',    'CTF'; ...
         {'.fif'},               'MEG/EEG: Elekta-Neuromag (*.fif)',     'FIF'; ...
         {'*'},                  'EEG: ASCII text (*.*)',                'EEG-ASCII'; ...
         {'.avr','.mux','.mul'}, 'EEG: BESA exports (*.avr;*.mul;*.mux)','EEG-BESA'; ...
         {'.eeg','.dat'},        'EEG: BrainAmp (*.eeg;*.dat)',          'EEG-BRAINAMP'; ...
         {'.txt'},               'EEG: BrainVision Analyzer (*.txt)',    'EEG-BRAINVISION'; ...
         {'.sef','.ep','.eph'},  'EEG: Cartool (*.sef;*.ep;*.eph)',      'EEG-CARTOOL'; ...
         {'.edf','.rec'},        'EEG: EDF / EDF+ (*.rec;*.edf)',        'EEG-EDF'; ...
         {'.set'},               'EEG: EEGLAB (*.set)',                  'EEG-EEGLAB'; ...
         {'.raw'},               'EEG: EGI Netstation RAW (*.raw)',      'EEG-EGI-RAW'; ...
         {'.erp','.hdr'},        'EEG: ERPCenter (*.hdr;*.erp)',         'EEG-ERPCENTER'; ...
         {'.mat'},               'EEG: Matlab matrix (*.mat)',           'EEG-MAT'; ...
         {'.cnt','.avg','.eeg','.dat'}, 'EEG: Neuroscan (*.cnt;*.eeg;*.avg;*.dat)', 'EEG-NEUROSCAN'; ...
         {'.mat'},               'NIRS: MFIP (*.mat)',                   'NIRS-MFIP'; ...
        }, DefaultFormats.DataIn);
    
if isempty(Lst) 
    ctrl.jradwit.setSelected(1);
    check_time('bsl', '', '');
    return
end

ctrl.jTextBSL.setText(Lst);
MEMglobal.BSLinfo.file    = Lst;
MEMglobal.BSLinfo.format  = Frmt; 

if strcmp(Frmt, 'BST-MAT')
    BSL     =   load( Lst );
    BSLc    =   load( fullfile( iP.STUDIES, bst_get('ChannelFileForStudy', Lst) ) );
else
    try
        [BSL, BSLc] = in_data( Lst, Frmt, [], []);
        if numel(BSL)>1
            ctrl.jTextBSL.setText('loading only trial 1');
            pause(1)
            ctrl.jTextBSL.setText(Lst);
        end    
        BSL = load(BSL(1).FileName);
    catch
        ctrl.jTextBSL.setText('File cannot be used. Select new file');
        pause(1)
        ctrl.jTextBSL.setText('');
        ctrl.jradimp.setSelected(0);
        ctrl.jradwit.setSelected(1);        
    end
end

MEMglobal.Baseline              = BSL.F;
MEMglobal.BaselineTime          = BSL.Time;
MEMglobal.BaselineChannels      = BSLc;
MEMglobal.BaselineHistory{1}    = 'import';
MEMglobal.BaselineHistory{2}    = '';
MEMglobal.BaselineHistory{3}    = Lst;

check_time('bsl', 'import', 'true', 'checkOK');

end

function adjust_range(WTA, rng)

% Get info
ctrl =  bst_get('PanelControls', 'InverseOptionsMEM');
VAL  =  str2double( char(ctrl.(WTA).getText()) ); 

% custom range
if strcmp(WTA, 'jVarCovar')
    idX     =   [ctrl.jMEMdef.isSelected() ctrl.jMEMw.isSelected() ctrl.jMEMr.isSelected()];
    rng     =   rng{idX};
end

% adjust value
VAL  =  max( VAL, rng(1) );
VAL  =  min( VAL, rng(2) );

% set value
ctrl.(WTA).setText( num2str(VAL) );

end

function load_default_baseline(varargin)

global MEMglobal

if isfield(MEMglobal, 'BaselineHistory') && strcmp(MEMglobal.BSLinfo.file, MEMglobal.BaselineHistory{3})
    check_time('bsl', 'default', 'true');
    return
end

iP = bst_get('ProtocolInfo');
FL = load( fullfile(iP.STUDIES, MEMglobal.BSLinfo.file) );
BSLc    =   load( fullfile(iP.STUDIES, bst_get('ChannelFileForStudy', iP.iStudy) ));
MEMglobal.Baseline              = FL.F;
MEMglobal.BaselineTime          = FL.Time;
MEMglobal.BaselineChannels      = BSLc;
MEMglobal.BaselineHistory{1}    = 'default';
MEMglobal.BaselineHistory{2}    = MEMglobal.BSLinfo.comment;
MEMglobal.BaselineHistory{3}    = MEMglobal.BSLinfo.file;

check_time('bsl', 'default', 'true');

end

function load_emptyroom_noise(varargin)

global MEMglobal
iP  =   bst_get('ProtocolInfo');

% Get info
if ~isfield(MEMglobal, 'EmptyRoomData') || isempty(MEMglobal.EmptyRoomData)
    %load emptyroom noise
    if numel(MEMglobal.ERDinfo.file)>1
        fprintf('panel_brainentropy:\tfound more than 1 emptyroom data\n\tselection is arbitrary\n');
    else
        fprintf('panel_brainentropy:\tloading emptyroom noise\n')       
    end
    L           =   load( fullfile(iP.STUDIES, MEMglobal.ERDinfo.file{1}) );
    [dum, iS]   =   bst_get('Study', fullfile( bst_fileparts(MEMglobal.ERDinfo.file{1}), 'brainstormstudy.mat' ) );
    CH          =   bst_get('ChannelForStudy', iS);
    if ~isempty(CH)
        CH                              =   load( fullfile(iP.STUDIES, CH.FileName) );
        MEMglobal.EmptyRoomData         =   L.F;
        MEMglobal.EmptyRoomChannels     =   {CH.Channel.Name};
    else
        error('>>BEst error: could not find channel file for empty room data');
        
    end
    
else
    MEMglobal.EmptyRoomData         = [];
    
end

end

function set_scales(time)
    
    global MEMglobal
    ctrl =  bst_get('PanelControls', 'InverseOptionsMEM');   
    if numel(time)>127 && ~isfield(MEMglobal, 'selected_scale_index')

        if ~isfield(MEMglobal, 'available_scales')
            Nj      = fix( log2(numel(time)) );
            sf      = 1/diff(time([1 2]));
            Noff    = min(Nj-1, 3);

            scalesU = 1./2.^(1:Nj-Noff) * sf;
            scalesD = 1./2.^(1:Nj-Noff)/2 * sf;

            MEMglobal.available_scales  = [scalesU; scalesD];
        end
            
        % Fill fields
        ctrl.jWavScales.insertItemAt( '', 0)
        ctrl.jWavScales.insertItemAt( 'all', 1)
        for ii = 1 : size(MEMglobal.available_scales,2)
            IT = [num2str(ii) ' (' num2str(MEMglobal.available_scales(2,ii)) ':' num2str(MEMglobal.available_scales(1,ii)) ' Hz)'];
            ctrl.jWavScales.insertItemAt(IT, ii+1);
        end
        ctrl.jWavScales.setSelectedIndex(0); 
        
    elseif numel(time)<128
        ctrl.jWavScales.insertItemAt( 'NOT ENOUGH SAMPLES', 0)
        ctrl.jWavScales.insertItemAt( 'NOT ENOUGH SAMPLES', 1)
        ctrl.jWavScales.setSelectedIndex(0); 
        ctrl.jWavScales.setEnabled(0);
        
    else
        ctrl.jWavScales.setSelectedIndex(MEMglobal.selected_scale_index);
        
    end
             
end

function [freqs] = set_freqs(time)

    global MEMglobal
    ctrl = bst_get('PanelControls', 'InverseOptionsMEM');

    if ~isfield(MEMglobal, 'selected_freqs_index') && numel(time)>127
        
        if ~isfield(MEMglobal, 'freqs_available')
            O.wavelet.vanish_moments=   str2double( ctrl.jWavVanish.getText() );
            O.wavelet.order     	=   str2double( ctrl.jWavOrder.getText() );
            O.wavelet.nb_levels  	=   str2double( ctrl.jWavLevels.getText() );
            O.wavelet.verbose       =   0;  
            O.mandatory.DataTime    =   time;

            [dum, O] = be_cwavelet( time, O, 1);
            FRQ = O.wavelet.freqs_analyzed;

            freqs = {'','all'};
            if max(FRQ)>100    
                if min( abs(FRQ-30) ) < 1
                    freqs = [freqs {'gamma'}];        
                    if min( abs(FRQ-13) ) < 1
                        freqs = [freqs {'beta'}];            
                        if min( abs(FRQ-8) ) < 1
                            freqs = [freqs {'alpha'}];                
                            if min( abs(FRQ-4) ) < 1
                                freqs = [freqs {'theta'}];                   
                                if min( abs(FRQ-1) ) < 1
                                    freqs = [freqs {'delta'}];
                                end
                            end
                        end
                    end
                end
            end
            MEMglobal.freqs_available = freqs;
            MEMglobal.freqs_analyzed  = FRQ;
        end
        
        % Fill fields
        for ii = 1 : numel(MEMglobal.freqs_available)
            ctrl.jRDGrangeS.insertItemAt(MEMglobal.freqs_available{ii}, ii-1);
        end        
        ctrl.jRDGrangeS.setSelectedIndex(0);   
    
    elseif numel(time)<128
        ctrl.jRDGrangeS.insertItemAt( 'NOT ENOUGH SAMPLES', 0)
        ctrl.jRDGrangeS.insertItemAt( 'NOT ENOUGH SAMPLES', 1)
        ctrl.jRDGrangeS.setSelectedIndex(0); 
        ctrl.jRDGrangeS.setEnabled(0); 
        
    else
        ctrl.jRDGrangeS.setSelectedIndex(MEMglobal.selected_freqs_index);
     
    end
    
end

function rememberTFindex(type)
    
    global MEMglobal
    ctrl =  bst_get('PanelControls', 'InverseOptionsMEM');
    switch type
        case 'scales'
            MEMglobal.selected_scale_index = ctrl.jWavScales.getSelectedIndex;
            ctrl.jWavScales.removeItemAt( 0 );
            ctrl.jWavScales.insertItemAt( ctrl.jWavScales.getSelectedItem(),0 );
            
        case 'freqs'
            MEMglobal.selected_freqs_index = ctrl.jRDGrangeS.getSelectedIndex;
            ctrl.jRDGrangeS.removeItemAt( 0 );
            ctrl.jRDGrangeS.insertItemAt( ctrl.jRDGrangeS.getSelectedItem(),0 );
    end

end
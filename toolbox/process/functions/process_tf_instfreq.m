function varargout = process_tf_instfreq( varargin )
% PROCESS_TF_INSTFREQ: Calculate instantaneous frequency from the phase information of a complex signal.
%
% USAGE:  TimefreqMat = process_tf_instfreq('Compute', TimefreqMat, FreqBands, TimeBands)

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
% Authors: Francois Tadel, 2013

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Instantaneous frequency [Experimental]';
    sProcess.Category    = 'File';
    sProcess.SubGroup    = 'Frequency';
    sProcess.Index       = 512;
    sProcess.Description = '';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'timefreq'};
    sProcess.OutputTypes = {'timefreq'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.isSeparator = 1;
    % Option: Method
    sProcess.options.ifmethod.Comment = {'baillet', 'auger', 'auger_ml', 'taner'};
    sProcess.options.ifmethod.Type    = 'radio';
    sProcess.options.ifmethod.Value   = 1;
    % Option: Auger_ML parameter L
    sProcess.options.augerl.Comment = 'auger_ml L parameter (>=2): ';
    sProcess.options.augerl.Type    = 'value';
    sProcess.options.augerl.Value   = {2,'',0};
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFile = Run(sProcess, sInput) %#ok<DEFNU>
    OutputFile = [];
    % Get options
    IfMethod = sProcess.options.ifmethod.Comment{sProcess.options.ifmethod.Value};
    param = sProcess.options.augerl.Value{1};
    % Load TF file
    TimefreqMat = in_bst_timefreq(sInput.FileName, 0);
    % Check method and measure applied on the data
    if ~ismember(TimefreqMat.Method, {'hilbert', 'morlet', 'mtmconvol'}) || ~strcmpi(TimefreqMat.Measure, 'none')
        bst_report('Error', sProcess, sInput, 'This function only applies to Hilbert or Morlet complex coefficients.');
        return;
    end
    % Call function to calculate the instantaneous frequency
    TimefreqMat.TF = Compute(TimefreqMat.Time, TimefreqMat.TF, IfMethod, param);
    % Change the measure to "other"
    TimefreqMat.Measure = 'other';
    TimefreqMat.Method  = 'instfreq';
    % Comment
    TimefreqMat.Comment = [TimefreqMat.Comment, ' | instfreq'];
    % Remove the '_hilbert' tag in the filename
    FileName = strrep(file_fullpath(sInput.FileName), '_hilbert', '');
    % Output filename: add file tag
    OutputFile = strrep(FileName, '.mat', '_instfreq.mat');
    OutputFile = file_unique(OutputFile);
    % Save file
    bst_save(OutputFile, TimefreqMat, 'v6');
    % Add file to database structure
    db_add_data(sInput.iStudy, OutputFile, TimefreqMat);
end


%% ===== COMPUTE =====
function IF = Compute(Time, TF, IfMethod, L)
    % Method not specified: use default
    if (nargin < 3) || isempty(IfMethod)
        IfMethod = 'baillet';
    end
    % Get the time vector, and replace the 0 value with Inf
    t = Time - Time(1);
    dt = Time(2) - Time(1);
    % Switch amongst methods
    switch lower(IfMethod)
        case 'baillet'
            % Calulate instantaneous frequency
            IF = abs( diff(unwrap(angle(TF),[],2),[],2) ) ./ (2 * pi * dt);
            IF = [IF, IF(:,end,:)];
            
        case 'auger'
            % Computes the (normalized) instantaneous frequency of the signal X defined as angle(X(T+1)*conj(X(T-1)) ;
            % Coming from function instfreq of the Time-frequency toolbox
            %	F. Auger, March 1994, July 1995.
            %	Copyright (c) 1996 by CNRS (France).
            IF = 0.5 * (angle(-TF(:,3:end,:) .* conj(TF(:,1:end-2,:))) + pi) / (2 * pi);
            IF = [IF, IF(:,end,:), IF(:,end,:)];
            
        case 'auger_ml'
            % Maximum Likelihood estimation of the instantaneous frequency of the deterministic part of the signal blurried in a white gaussian noise.
            % Coming from function instfreq of the Time-frequency toolbox
            %	F. Auger, March 1994, July 1995.
            %	Copyright (c) 1996 by CNRS (France).
            % Kay-Tretter filter computation
            pp1 = L * (L+1);
            den = 2.0 * L * (L+1) * (2.0*L + 1.0) / 3.0;
            i = 1:L; 
            H = pp1 - i.*(i-1);
            H = H ./ den;
            % Redefine t
            t = 2:size(TF,2)-1;
            IF = zeros(size(TF));
            % Process each signal separately for now
            for is = 1:size(TF,1)
                for iF = 1:size(TF,3)
                    for it = L:length(t)-L
                        tau = 0:L;
                        R = TF(is, t(it)+tau, iF) .* conj(TF(is, t(it)-tau, iF));
                        R = R';
                        M4 = R(2:L+1) .* conj(R(1:L));

                        d = 2e-6;
                        tetapred = H * (unwrap(angle(-M4))+pi);
                        while (tetapred < 0.0)
                            tetapred = tetapred + (2*pi);
                        end
                        while tetapred > 2*pi
                            tetapred = tetapred - (2*pi); 
                        end
                        iter = 1;
                        while (d > 1e-6) && (iter<50)
                            M4bis = M4 .* exp(-1i*2.0*tetapred);
                            teta = H * (unwrap(angle(M4bis))+2.0*tetapred);
                            while teta<0.0
                                teta=(2*pi)+teta; 
                            end
                            while teta>2*pi
                                teta=teta-(2*pi); 
                            end
                            d = abs(teta-tetapred);
                            tetapred = teta; 
                            iter = iter+1;
                        end;
                        IF(is, it, iF) = teta/(2*pi);
                    end
                end
            end
            
        case 'taner'
            % Coming from a paper pointed out by Sergul: AE Barnes, 1992
            % Pointing to [Taner, 1979]
            % IF(t) = 1/2pi * (x*y' - x'*y) / (x^2 + y^2)
            
            x = real(TF);
            dx = diff(x,[],2) / dt;
            dx = [dx, dx(:,end,:)];

            y = imag(TF);
            dy = diff(y,[],2) / dt;
            dy = [dy, dy(:,end,:)];

            IF = (x.*dy - dx.*y) ./ (x.^2 + y.^2) ./ (2 * pi);            
    end
end



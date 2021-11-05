function [valScaled, valFactor, valUnits] = bst_getunits( val, DataType, FileName)
% BST_GETUNITS: Get in which units is expressed a value.
%
% USAGE:  [valScaled, valFactor, valUnits] = bst_getunits(val, DataType, FileName=[]);
%
% INPUT:
%    - val       : Value to analyze
%    - DataType  : Type of data in the value "val". Possible strings: 
%                  'EEG', 'MEG', 'MEG MAG', 'MEG GRAD', 'ECOG', 'SEEG', '$MEG', '$EEG', '$ECOG', '$SEEG', 'results', 'sources', 'source', 'stat', ...
%    - fUnits : Units of the file (eg "" if unknown, "cm", "pA", "mml/l")
% OUTPUT:
%    - valScaled : value in the detected units (val * valFactor)
%    - valFactor : factor to convert val -> valScaled
%    - valUnits  : string that represents the units ('\muV', 'fT', 'pA.m', etc.)

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
% Authors: Francois Tadel, 2008-2021
%          Edouard Delaire, 2021

% Check if there is something special in the filename
if (nargin >= 3) && ~isempty(FileName)
    % Source files
    if ismember(lower(DataType), {'results', 'sources', 'source'})
        % Detect sLORETA source files
        if ~isempty(strfind(lower(FileName), 'sloreta'));
            DataType = 'sloreta';
        % Detect NIRS source files
        elseif ~isempty(strfind(lower(FileName), 'nirs'))
            DataType = 'nirs-src';
        end
    end
end

% Consider input data in absolute value
val = abs(val);
% If no modality (ex: surface mask, mri values...)
if isempty(DataType)
    DataType = 'none';
end
% Units depends on the data modality
switch lower(DataType)
    case {'meg', '$meg', 'meg grad', 'meg mag', '$meg grad', '$meg mag', 'meg grad2', 'meg grad3', 'meg gradnorm'}
        % MEG data in fT
        if (val < 1e-8)
            valFactor = 1e15;
            valUnits  = 'fT';
        % MEG data without units (zscore, stat...)
        else
            valFactor = 1;
            valUnits  = 'No units';
        end
        
    case {'eeg', '$eeg', 'ecog', '$ecog', 'seeg', '$seeg', 'eog', '$eog', 'ecg', '$ecg', 'emg', '$emg'}
        % EEG data in Volts, displayed in microVolts
        if (val < 0.01)
            valFactor = 1e6;
            valUnits = '\muV';
        % EEG data in Volts, displayed in milliVolts
        elseif (val < 1)
            valFactor = 1e3;
            valUnits = 'mV';
        % EEG data without units (zscore, stat...)
        else
            valFactor = 1;
            valUnits = 'No units';
        end
    case  'nirs-src'
        if ~isempty(strfind(lower(FileName), 'hb')) 
             [valFactor, valUnits] = GetSIFactor(val, '\mumol.l-1');
        else
             [valFactor, valUnits] = GetExponent(val);
        end     
    case {'nirs', '$nirs'}
        % Try reading DisplayUnits field from file
        fUnits = [];
        if (nargin >= 3) && ~isempty(FileName)
            tmp = load(file_fullpath(FileName), 'DisplayUnits');
            if ~isempty(tmp.DisplayUnits)
                fUnits = tmp.DisplayUnits;
            end
        end
        if ~isempty(fUnits) && ~isempty(strfind(fUnits, 'mol'))
            [valFactor, valUnits] = GetSIFactor(val, fUnits);
        elseif ~isempty(fUnits) && ~isempty(strfind(fUnits, 'cm'))
            valFactor = 1;
            valUnits  = 'cm';
        elseif ~isempty(fUnits)
            [valFactor, valUnits] = GetExponent(val);
            valUnits = sprintf('%s(%s)',fUnits,valUnits);
        else    
            [valFactor, valUnits] = GetExponent(val);
        end   
    case {'results', 'sources', 'source'}
        % Results in Amper.meter (display in picoAmper.meter)
        if (val < 1e-4)
            valFactor = 1e12;
            valUnits  = 'pA.m';
        % Results without units (zscore, stat...)
        else
            valFactor = 1;
            valUnits  = 'No units';
        end
        
    case 'sloreta'
        if (val < 1e-4)
            [valFactor, valUnits] = GetExponent(val);
        else
            valFactor = 1;
            valUnits  = 'No units';
        end
        
    case 'stat'
        if (val < 1e-13)
            [valFactor, valUnits] = GetExponent(val);
        elseif (val < 1e-8)
            valFactor = 1e12;
            valUnits  = 'pA.m';
        elseif (val < 1e-3)
            [valFactor, valUnits] = GetExponent(val);
        else
            valFactor = 1;
            valUnits  = 'No units';
        end
        
    case 'connect'
        valFactor = 1;
        valUnits  = 'score';
        
    case 'timefreq'
        [valFactor, valUnits] = GetExponent(val);
        
    case 'hlu'
        valFactor = 1e3;
        valUnits  = 'mm';
        
    otherwise
        if isempty(val) || ((val < 1000) && (val > 0.1))
            valFactor = 1;
            valUnits  = 'No units';
        else
            [valFactor, valUnits] = GetExponent(val);
        end
end
% Scale input value
valScaled = val .* valFactor;

end

%% ===== GET EXPONENT =====
function [valFactor, valUnits] = GetExponent(val)
    if (val == 0)
        valFactor = 1;
        valUnits  = 'No units';
    else
        %exponent = round(log(val)/log(10) / 3) * 3;
        exponent = round(log(val)/log(10)) - 1;
        % Do not allow 10^-1 and 10^-2
        if (exponent == -1) || (exponent == -2)
            valFactor = 1;
            valUnits  = 'No units';
        else
            valFactor = 10 ^ -exponent;
            valUnits  = sprintf('10^{%d}', exponent);
        end
    end
end

function [valFactor, valUnits] = GetSIFactor(val, originalUnit)
    vpw = [    -24,    -21,   -18,    -15,   -12,    -9,     -6,   -3, 0   +3,    +6,    +9,   +12,   +15,  +18,    +21,    +24];
    pfn = {'yocto','zepto','atto','femto','pico','nano','micro','milli','','kilo','mega','giga','tera','peta','exa','zetta','yotta'};
    pfs = {'y'    ,'z'    ,'a'   ,'f'    ,'p'   ,'n'   ,'\mu'    ,'m' ,'','k'   ,'M'   ,'G'   ,'T'   ,'P'   ,'E'  ,'Z'    ,'Y'    };
    sgf = 5;
    dpw = mode(diff(vpw));
    
    
    [unit, modifier] = getUnit(originalUnit);
    if abs(val) < eps
        valFactor = 1;
        valUnits = originalUnit;
        return
    end    
    
    adj = n2pAdjust(log10(abs(val)),dpw);
    
    vec = val./10.^adj;
    % Determine the number of decimal places:
    p10 = 10.^(sgf-1-floor(log10(abs(vec))));
    % Round coefficients to decimal places:
    vec = round(vec.*p10)./p10;
    % Identify which prefix is required:
    idx = 1+any(abs(vec)==[10.^dpw,1]);
    pwr = 1+floor(log10(abs(vec(idx))));
    
    % Obtain the required prefix index:
    idp = find(adj(idx)==vpw);
    
    valFactor = 10^(- vpw(idp));
    valUnits  = sprintf('%s%s',pfs{idp + modifier}, unit);
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%num2sip
function adj = n2pAdjust(pwr,dPw)
adj = dPw*((0:1)+floor(floor(pwr)/dPw));
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%n2pAdjust
function [unit, modifier] = getUnit(data)
% return the unit and the modifier from a string
% getUnit('mol/l') should return mol/l and 0
% getUnit('mmol/l') should return mol/l and -1 
% getUnit('pA') should return A and -4 


pfs = {'y'    ,'z'    ,'a'   ,'f'    ,'p'   ,'n'   ,'\mu'    ,'m' ,'','k'   ,'M'   ,'G'   ,'T'   ,'P'   ,'E'  ,'Z'    ,'Y'    };
vpw = [    -24,    -21,   -18,    -15,   -12,    -9,     -6,   -3, 0   +3,    +6,    +9,   +12,   +15,  +18,    +21,    +24];

Units = {'A','mol.l-1'};

unit = Units{cellfun(@(x)contains(data,x), Units)};
modifier = find(strcmp(strcat(pfs,unit),data)) - 9 ;

end

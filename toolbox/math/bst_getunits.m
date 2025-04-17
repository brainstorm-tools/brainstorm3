function [valScaled, valFactor, valUnits] = bst_getunits( val, DataType, FileName, DisplayUnits)
% BST_GETUNITS: Get in which units is expressed a value.
%
% USAGE:  [valScaled, valFactor, valUnits] = bst_getunits(val, DataType, FileName=[], DisplayUnits=[]);
%
% INPUT:
%    - val       : Value to analyze
%    - DataType  : Type of data in the value "val". Possible strings: 
%                  'EEG', 'MEG', 'MEG MAG', 'MEG GRAD', 'ECOG', 'SEEG', '$MEG', '$EEG', '$ECOG', '$SEEG', 'results', 'sources', 'source', 'stat', ...
%    - fUnits : Units of the file (eg "" if unknown, "cm", "pA", "mml/l")
%    
% OUTPUT:
%    - valScaled : value in the detected units (val * valFactor)
%    - valFactor : factor to convert val -> valScaled
%    - valUnits  : string that represents the units ('\muV', 'fT', 'pA.m', etc.)

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
% Authors: Francois Tadel, 2008-2022
%          Edouard Delaire, 2021-2022

% Parse inputs
if (nargin < 4) || isempty(DisplayUnits)
    DisplayUnits = [];
end

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

% If the display unit is already defined
if ~isempty(DisplayUnits)
    if ismember(lower(DataType), {'nirs', '$nirs','nirs-src'})
        if ~isempty(strfind(DisplayUnits, 'mol'))
            [valFactor, valUnits] = GetSIFactor(val, DisplayUnits);
        elseif ~isempty(strfind(DisplayUnits, 'cm'))
            valFactor = 1;
            valUnits  = 'cm';
        elseif ~isempty(strfind(DisplayUnits, 'delta'))
            [valFactor, valUnits] = GetExponent(val);
            valUnits = sprintf('%s(%s)',strrep(DisplayUnits,'delta ','\Delta'),valUnits);
        else
            [valFactor, valUnits] = GetExponent(val);
            iParent =  find(DisplayUnits == '(');
            if ~isempty(iParent) 
                DisplayUnits = DisplayUnits(1:iParent-1);
            end
            valUnits = sprintf('%s(%s)',DisplayUnits,valUnits);
        end
    else
        valUnits = DisplayUnits;
        switch (DisplayUnits)
            case 'fT'
                valFactor = 1e15;
            case 'pA.m'
                valFactor = 1e12;
            case '\muV'
                valFactor = 1e6;
            case {'mV', 'mm'}
                valFactor = 1e3;
            otherwise
                valFactor = 1;
        end
    end

% Otherwise: Units depends= on the data modality
else
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
        case {'nirs', '$nirs','nirs-src'}
             [valFactor, valUnits] = GetExponent(val);
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
            
        case {'ica', 'ssp'}
            [valFactor, valUnits] = GetExponent(val);
            if (valFactor == 0)
                valUnits = 'a.u.';
            else
                valUnits = ['x' valUnits ' a.u.'];
            end
    
        otherwise
            if isempty(val) || ((val < 1000) && (val > 0.1))
                valFactor = 1;
                valUnits  = 'No units';
            else
                [valFactor, valUnits] = GetExponent(val);
            end
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
%GETSIFACTOR Converts a small numerical value to an SI-prefixed format.
%
%   [valFactor, valUnits] = GETSIFACTOR(val, originalUnit)
%
%   This function finds the appropriate SI prefix to represent a small
%   numerical value `val` in a more human-readable format, particularly
%   when `val` is significantly smaller than 1. It returns a multiplicative
%   factor (`valFactor`) and the updated unit string with an SI prefix
%   (`valUnits`).
%
%   INPUTS:
%       val           - A numeric scalar value (e.g., 3.2e-6)
%       originalUnit  - A string representing the unit of the value
%                       (e.g., 'V', 'mA', etc.). Can include a prefix.
%
%   OUTPUTS:
%       valFactor     - The factor by which the input value should be
%                       multiplied to apply the SI prefix. For example,
%                       if val = 3.2e-6 and the prefix is μ, then
%                       valFactor = 1e6 (i.e., 3.2 = val * valFactor).
%       valUnits      - A string representing the new unit with the
%                       appropriate SI prefix applied (e.g., 'μV').
%
    % Configuration
    decPowerStep = 3;
    sigFigs      = 5;
    siPowers     = -24:decPowerStep:24;
    siPrefixes   = {'y','z','a','f','p','n','\mu','m','','k','M','G','T','P','E','Z','Y'};


    % Extract base unit (remove any prefix)
    unit = getUnit(originalUnit);

    % Compute possible decimal adjustments
    exponentFloor     = floor(log10(abs(val)));
    adjustedExponents = decPowerStep * ((0:1) + floor(exponentFloor / decPowerStep));
    adjustedValues    = val ./ 10.^adjustedExponents;

    % Round to significant figures
    powerTen = 10.^(sigFigs - 1 - floor(log10(abs(adjustedValues))));
    roundedValues = round(adjustedValues .* powerTen) ./ powerTen;

    % Determine index for best prefix
    idx = 1 + any(abs(roundedValues) == [10^decPowerStep, 1]);
    targetExponent = adjustedExponents(idx);

    % Find corresponding SI prefix
    prefixIndex = find(siPowers == targetExponent, 1);

    % If no valid prefix found, return original
    if isempty(prefixIndex)
        valFactor = 1;
        valUnits = originalUnit;
        return;
    end

    % Compute output
    valFactor   = 10^(-siPowers(prefixIndex));
    valUnits    = sprintf('%s%s', siPrefixes{prefixIndex}, unit);
end


function [unit, modifier] = getUnit(data)
%GETUNIT Extracts the base unit and SI prefix modifier from a unit string.
%
%   [unit, modifier] = GETUNIT(data)
%
%   This function parses a unit string with a possible SI prefix (e.g., 'pA',
%   'mmol/l') and returns the base unit without the prefix and a corresponding
%   numeric modifier indicating the power of 10 the prefix represents.
%
%   INPUT:
%       data - A string containing a unit with an optional SI prefix.
%
%   OUTPUT:
%       unit     - The base unit string (e.g., 'A', 'mol/l')
%       modifier - The power of 10 associated with the SI prefix.
%                  For example, 'p' -> -12, 'm' -> -3, 'k' -> +3, etc.
%                  If no prefix is found, returns 0.
%
%   EXAMPLES:
%       getUnit('mol/l')   returns 'mol/l', 0
%       getUnit('mmol/l')  returns 'mol/l', -3
%       getUnit('pA')      returns 'A', -12

    % SI prefix symbols and corresponding powers of ten
    prefixes = {'y','z','a','f','p','n','\mu','m','','k','M','G','T','P','E','Z','Y'};
    powers   = -24:3:24;

    % Define the base units you expect
    knownUnits = {'A', 'mol/l', 'mol.l-1'};  % Support both 'mol/l' and 'mol.l-1'

    % Try to match any unit suffix
    for iUnit = 1:length(knownUnits)
        base = knownUnits{iUnit};
        for jPrefix = 1:length(prefixes)
            candidate = strcat(prefixes{jPrefix}, base);
            if strcmp(data, candidate)
                unit = base;
                modifier = powers(jPrefix);
                return;
            end
        end
    end

    % If no match found, assume no prefix and return input as-is
    unit = data;
    modifier = 0;
end

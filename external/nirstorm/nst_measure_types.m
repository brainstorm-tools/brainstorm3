function measure_types = nst_measure_types()
% NST_MEASURE_TYPES return an enumeration of measure types (eg wavelength, Hb)
%
% MEASURE_TYPES = NST_MEASURE_TYPES()
%    MEASURE_TYPES: struct with numerical fields listing all available
%                   channel types:
%                   - MEASURE_TYPES.WAVELENGTH
%                   - MEASURE_TYPES.Hb

measure_types.WAVELENGTH = 1;
measure_types.HB = 2;
end
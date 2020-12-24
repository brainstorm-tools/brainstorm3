function [unit, conversion] = get_channel_info(elec_info)

unit = elec_info.AnalogUnits;
unit = unit(logical(unit));

conversion = single((elec_info.MaxAnalogValue - elec_info.MinAnalogValue)) /  ...
    single((elec_info.MaxDigiValue - elec_info.MinDigiValue));
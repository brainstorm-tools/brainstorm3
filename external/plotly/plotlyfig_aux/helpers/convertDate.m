function converted = convertDate(date)
   converted = (date - datenum(1969,12,31,19,00,00))*1000*60*60*24;
end
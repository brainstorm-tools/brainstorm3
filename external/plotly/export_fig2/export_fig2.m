function export_fig2(fig, beautify, filename, format)

%----INPUT----% 
% fig: handle of figure to be converted
% beautify: binary flag 1 = use Plotly defaults, 0 = use MATLAB defaults
% fielname: name of file to be saved to specified directory
% format: one of 'png' (default), 'pdf', 'jpeg', 'svg'

%-------------------------------------------------------------------------%

%--CONSTRUCT PLOTLY FIGURE OBJECT--%
p = plotlyfig(fig, 'strip', beautify);

%-------------------------------------------------------------------------%

%----SAVE IMAGE-----%
saveplotlyfig(p, filename, format);

%-------------------------------------------------------------------------%

end
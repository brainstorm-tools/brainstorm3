function p = fig2plotly(varargin)

%------------------------------FIG2PLOTLY---------------------------------%

% Convert a MATLAB figure to a Plotly Figure

% [CALL]:

% p = fig2plotly
% p = fig2plotly(fig_han)
% p = fig2plotly(fig_han, 'property', value, ...)

% [INPUTS]: [TYPE]{default} - description/'options'

% fig_han: [handle]{gcf} - figure handle
% fig_struct: [structure array]{get(gcf)} - figure handle structure array

% [VALID PROPERTIES / VALUES]:

% filename: [string]{'untitled'} - filename as appears on Plotly
% fileopt: [string]{'new'} - 'new, overwrite, extend, append'
% world_readable: [boolean]{true} - public(true) / private(false)
% link: [boolean]{true} - show hyperlink (true) / no hyperlink (false)
% open: [boolean]{true} - open plot in browser (true)

% [OUTPUT]:

% p - plotlyfig object

% [ADDITIONAL RESOURCES]:

% For full documentation and examples, see https://plot.ly/matlab

%-------------------------------------------------------------------------%

%--FIGURE INITIALIZATION--%
if nargin == 0
    varargin{1} = gcf; 
end

%-------------------------------------------------------------------------%

%--CONSTRUCT PLOTLY FIGURE OBJECT--%
p = plotlyfig(varargin{:});

%-------------------------------------------------------------------------%

%--MAKE CALL TO PLOTLY--%
p.plotly; 

%-------------------------------------------------------------------------%

end

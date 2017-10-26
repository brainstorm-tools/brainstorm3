function errormsg = plotlymsg(key)
switch key
    %--plotlyfig constructor--%
    case 'plotlyfigConstructor:notSignedIn'
        errormsg = '\nOops! You must be signed in to initialize a plotlyfig object.\n'; 
    case 'plotlyfigConstructor:invalidInputs'
        errormsg = ['\nOops! It appears that you did not initialize the plotlyfig object using the\n', ...
            'required: >>  plotlyfig(handle [optional],''property'',''value'',...) \n',...
            'input structure. Please try again or contact chuck@plot.ly for any additional help!\n\n'];
        %--saveplotlyfig invocation--%;
    case 'plotlySaveImage:invalidInputs'
        errormsg = ['\nOops! It appears that you did not invoke the saveplotlyfig function using the\n', ...
            'required: >>  saveplotlyfig(plotly_figure, ...) input structure, where plotly_figure\n',...
            'is of type cell (for data traces) or of type struct (with data and layout fields). \n',...
            'Please try again or contact chuck@plot.ly for any additional help!\n\n'];
        
end
end

Plotly - Create publication quality graphs, all in your web browser!
------

Plotly (https://plot.ly) is a browser-based data analysis and visualization tool that creates interactive, customizable, publication quality figures.

This API allows MATLAB users to generate Plotly graphs from their desktop MATLAB environment. 

All graphs can be styled and shared through Plotly's interactive web application.
To use, simply:

0. sign-up (either online or using signup.m) 
1. run plotlysetup('username','api_key') (both username and api_key can be found online!)
3. call: >> fig2plotly to convert your MATLAB figure!
4. View, style and share your plot in your browser at Plotly (https://plot.ly)

See full documentation and examples at https://plot.ly/matlab 

New Features
------------
- plotlyupdate: automatically update the Plotly API Matlab libraries in your MATLAB search path to match the latest release! 
- getplotlyfig('username','figure_id'): grab the data and layout information from any publicly available graph online! 
- saveplotlyfig(figure,'image_name','ext'): convert your plotly figure into a high-quality static (png,pdf,svg,jpef) image for your publications!
- plotlystream: stream your data directly from MATLAB to your plotly account in real-time! 

Example Graphs
--------------
Scatter - https://plot.ly/~chris/514/
Scatter + Line - https://plot.ly/~jackp/614/
Stacked Bar - https://plot.ly/~jackp/655/
Grouped Bar - https://plot.ly/~jackp/540/700/500/
2D Histogram + Scatter - https://plot.ly/~chris/497/
1D Histogram - https://plot.ly/~chris/429/
Line - https://plot.ly/~jackp/645/
Area - https://plot.ly/~jackp/621/
Heatmap - https://plot.ly/~jackp/620/
Error Bars - https://plot.ly/~chris/421/


Plotly Features
---------------
- Send data to your Plotly account through this API
- Graphs are fully customizable through the Plotly web-app
- Rich colour and styling options
- View and style graphs interactively in your browser
- Publication quality exports to PNG, SVG, EPS, PDF
- Share graphs through links, Facebook, and Twitter


Example Workflow
----------------
1. Collect or generate some data in your MATLAB environment
2. Send data to your Plotly account through this Plotly-MATLAB API
3. View interactive graph in your browser, e.g.: https://plot.ly/~chris/407/
4. Style graph in the Plotly GUI
5. Share graph by shortlink, Facebook, or Twitter
6. Export to PNG, PDF, EPS, SVG


Documentation
-------------
Full documentation and examples at https://plot.ly/API

Questions? 
----------
Contact: chuck@plot.ly 
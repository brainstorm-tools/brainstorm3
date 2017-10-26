function plotlyFont = matlab2plotlyfont(matlabFont)

%Plotly supported fonts

try
%     availableFont = {'Arial, sans-serif',  'Balto, sans-serif' , ...
%         'Courier New, monospace' , 'Droid Sans, sans-serif' ,...
%         'Droid Serif, serif',  'Droid Sans Mono, sans-serif', ...
%         'Georgia, serif' ,  'Gravitas One, cursive' ,  ...
%         'Old Standard TT, serif' ,  'Open Sans, sans-serif', ...
%         'PT Sans Narrow, sans-serif' , 'Raleway, sans-serif',...
%         'Times New Roman, Times, serif'};
    
    switch matlabFont
        
        case 'Abadi MT Condensed Extra Bold'
            plotlyFont = 'Arial, sans-serif';
        case 'Abadi MT Condensed Light'
            plotlyFont = 'Balto, sans-serif';
        case 'Adobe Arabic'
            plotlyFont = 'Times New Roman, Times, serif';
        case 'Adobe Caslon Pro'
            plotlyFont = 'Times New Roman, Times, serif';
        case 'Adobe Fan Heiti Std'
            plotlyFont = 'Arial, sans-serif';
        case 'Adobe Fangsong Std'
            plotlyFont = 'Times New Roman, Times, serif';
        case 'Adobe Garamond Pro'
            plotlyFont = 'Times New Roman, Times, serif';
        case 'Adobe Gothic Std'
            plotlyFont = 'Arial, sans-serif';
        case 'Adobe Hebrew'
            plotlyFont = 'Times New Roman, Times, serif';
        case 'Adobe Heiti Std'
            plotlyFont = 'Droid Sans, sans-serif';
        case 'Adobe Kaiti Std'
            plotlyFont = 'Times New Roman, Times, serif';
        case 'Adobe Ming Std'
            plotlyFont = 'Times New Roman, Times, serif';
        case 'Adobe Myungjo Std'
            plotlyFont = 'Old Standard TT, serif';
        case 'Adobe Song Std'
            plotlyFont = 'Times New Roman, Times, serif';
        case 'Al Bayan'
            plotlyFont = 'Balto, sans-serif';
        case 'American Typewriter'
            plotlyFont = 'Old Standard TT, serif';
        case 'Andale Mono'
            plotlyFont = 'Droid Sans, sans-serif';
        case 'Apple Braille'
            plotlyFont = 'Balto, sans-serif';
        case'le Chancery'
            plotlyFont = 'Old Standard TT, serif';
        case 'Apple Color Emoji'
            plotlyFont = 'Balto, sans-serif';
        case 'Apple LiGothic'
            plotlyFont = 'Arial, sans-serif';
        case 'Apple LiSung'
            plotlyFont = 'Times New Roman, Times, serif';
        case 'Apple Symbols'
            plotlyFont = 'Balto, sans-serif';
        case 'AppleGothic'
            plotlyFont = 'Balto, sans-serif';
        case 'AppleMyungjo'
            plotlyFont = 'Old Standard TT, serif';
        case 'Arial'
            plotlyFont = 'Arial, sans-serif';
        case 'Arial Black'
            plotlyFont = 'Arial, sans-serif';
        case 'Arial Hebrew'
            plotlyFont = 'Arial, sans-serif';
        case 'Arial Narrow'
            plotlyFont = 'Arial, sans-serif';
        case 'Arial Rounded MT Bold'
            plotlyFont = 'Arial, sans-serif';
        case 'Arial Unicode MS'
            plotlyFont = 'Arial, sans-serif';
        case 'Ayuthaya'
            plotlyFont = 'Balto, sans-serif';
        case 'Baghdad'
            plotlyFont = 'Balto, sans-serif';
        case 'Bangla MN'
            plotlyFont ='Raleway, sans-serif';
        case 'Bangla Sangam MN'
            plotlyFont ='Raleway, sans-serif';
        case 'Baskerville'
            plotlyFont = 'Times New Roman, Times, serif';
        case 'Baskerville Old Face'
            plotlyFont = 'Times New Roman, Times, serif';
        case 'Batang'
            plotlyFont = 'Courier New, monospace';
        case 'Bauhaus 93'
            plotlyFont = 'Gravitas One, cursive';
        case 'Bell MT'
            plotlyFont = 'Times New Roman, Times, serif';
        case 'Bernard MT Condensed'
            plotlyFont = 'Gravitas One, cursive';
        case 'BiauKai'
            plotlyFont = 'Courier New, monospace';
        case 'Big Caslon'
            plotlyFont = 'Times New Roman, Times, serif';
        case 'Birch Std'
            plotlyFont = 'Droid Serif, serif';
        case 'Blackoak Std'
            plotlyFont = 'Gravitas One, cursive';
        case 'Book Antiqua'
            plotlyFont = 'Droid Serif, serif';
        case 'Bookman Old Style'
            plotlyFont = 'Balto, sans-serif';
        case 'Bookshelf Symbol 7'
            plotlyFont = 'Gravitas One, cursive';
        case 'Braggadocio'
            plotlyFont = 'Gravitas One, cursive';
        case 'Britannic Bold'
            plotlyFont = 'Courier New, monospace';
        case 'Brush Script MT'
            plotlyFont = 'Courier New, monospace';
        case 'Brush Script Std'
            plotlyFont = 'Courier New, monospace';
        case 'Calibri'
            plotlyFont = 'Balto, sans-serif';
        case 'Calisto MT'
            plotlyFont = 'Times New Roman, Times, serif';
        case 'Cambria'
            plotlyFont = 'Times New Roman, Times, serif';
        case 'Cambria Math'
            plotlyFont = 'Times New Roman, Times, serif';
        case 'Candara'
            plotlyFont = 'Raleway, sans-serif';
        case 'Century'
            plotlyFont = 'Times New Roman, Times, serif';
        case 'Century Gothic'
            plotlyFont = 'Balto, sans-serif';
        case 'Century Schoolbook'
            plotlyFont = 'Times New Roman, Times, serif';
        case 'Chalkboard'
            plotlyFont = 'Droid Sans, sans-serif';
        case 'Chalkduster'
            plotlyFont = 'Droid Sans, sans-serif';
        case 'Chaparral Pro'
            plotlyFont = 'Droid Serif, serif';
        case 'Charcoal CY'
            plotlyFont = 'Arial, sans-serif';
        case 'Charlemagne Std'
            plotlyFont = 'Old Standard TT, serif';
        case 'Cochin'
            plotlyFont = 'Old Standard TT, serif';
        case 'Colonna MT'
            plotlyFont = 'Times New Roman, Times, serif';
        case 'Comic Sans MS'
            plotlyFont = 'Droid Sans, sans-serif';
        case 'Consolas'
            plotlyFont = 'Balto, sans-serif';
        case 'Constantia'
            plotlyFont = 'Times New Roman, Times, serif';
        case 'Cooper Black'
            plotlyFont = 'Droid Sans, sans-serif';
        case 'Cooper Std'
            plotlyFont = 'Droid Sans, sans-serif';
        case 'Copperplate'
            plotlyFont = 'Old Standard TT, serif';
        case 'Copperplate Gothic Bold'
            plotlyFont = 'Old Standard TT, serif';
        case 'Copperplate Gothic Light'
            plotlyFont = 'Droid Serif, serif';
        case 'Corbel'
            plotlyFont = 'PT Sans Narrow, sans-serif';
        case 'Corsiva Hebrew'
            plotlyFont = 'Gravitas One, cursive';
        case 'Courier'
            plotlyFont = 'Courier New, monospace';
        case 'Courier New'
            plotlyFont = 'Courier New, monospace';
        case 'Curlz MT'
            plotlyFont = 'Gravitas One, cursive';
        case 'Damascus'
            plotlyFont = 'Arial, sans-serif';
        case 'DecoType Naskh'
            plotlyFont = 'Balto, sans-serif';
        case 'Desdemona'
            plotlyFont = 'Gravitas One, cursive';
        case 'Devanagari MT'
            plotlyFont = 'Old Standard TT, serif';
        case 'Devanagari Sangam MN'
            plotlyFont = 'Balto, sans-serif';
        case 'Dialog'
            plotlyFont = 'Raleway, sans-serif';
        case 'DialogInput'
            plotlyFont = 'Balto, sans-serif';
        case 'Didot'
            plotlyFont = 'Times New Roman, Times, serif';
        case 'Edwardian Script ITC'
            plotlyFont = 'Gravitas One, cursive';
        case 'Engravers MT'
            plotlyFont = 'Droid Serif, serif';
        case 'Euphemia UCAS'
            plotlyFont = 'Arial, sans-serif';
        case 'Eurostile'
            plotlyFont = 'Droid Sans, sans-serif';
        case 'Footlight MT Light'
            plotlyFont = 'Old Standard TT, serif';
        case 'Franklin Gothic Book'
            plotlyFont = 'Balto, sans-serif';
        case 'Franklin Gothic Medium'
            plotlyFont = 'Arial, sans-serif';
        case 'Futura'
            plotlyFont = 'Droid Sans, sans-serif';
        case 'Gabriola'
            plotlyFont = 'Gravitas One, cursive';
        case 'Garamond'
            plotlyFont = 'Times New Roman, Times, serif';
        case 'GB18030 Bitmap'
            plotlyFont = 'Arial, sans-serif';
        case 'Geeza Pro'
            plotlyFont = 'Balto, sans-serif';
        case 'Geneva'
            plotlyFont = 'Balto, sans-serif';
        case 'Geneva CY'
            plotlyFont = 'Arial, sans-serif';
        case 'Georgia'
            plotlyFont = 'Old Standard TT, serif';
        case 'Giddyup Std'
            plotlyFont = 'Gravitas One, cursive';
        case 'Gill Sans'
            plotlyFont = 'Arial, sans-serif';
        case 'Gill Sans MT'
            plotlyFont = 'Arial, sans-serif';
        case 'Gill Sans Ultra Bold'
            plotlyFont = 'Arial, sans-serif';
        case 'Gloucester MT Extra Condensed'
            plotlyFont = 'Droid Sans, sans-serif';
        case 'Goudy Old Style'
            plotlyFont = 'Times New Roman, Times, serif';
        case 'Gujarati MT'
            plotlyFont = 'Times New Roman, Times, serif';
        case 'Gujarati Sangam MN'
            plotlyFont = 'Balto, sans-serif';
        case 'Gulim'
            plotlyFont = 'Balto, sans-serif';
        case 'GungSeo'
            plotlyFont = 'Old Standard TT, serif';
        case 'Gurmukhi MN'
            plotlyFont = 'PT Sans Narrow, sans-serif';
        case 'Gurmukhi MT'
            plotlyFont = 'PT Sans Narrow, sans-serif';
        case 'Haettenschweiler'
            plotlyFont = 'Arial, sans-serif';
        case 'Harrington'
            plotlyFont = 'Gravitas One, cursive';
        case 'HeadLineA'
            plotlyFont = 'Arial, sans-serif';
        case 'Hei'
            plotlyFont = 'Balto, sans-serif';
        case 'Heiti SC'
            plotlyFont = 'Balto, sans-serif';
        case 'Heiti TC'
            plotlyFont = 'Balto, sans-serif';
        case 'Helvetica'
            plotlyFont = 'Arial, sans-serif';
        case 'Helvetica CY'
            plotlyFont = 'Arial, sans-serif';
        case 'Helvetica Neue'
            plotlyFont = 'Arial, sans-serif';
        case 'Herculanum'
            plotlyFont = 'Gravitas One, cursive';
        case 'Hiragino Kaku Gothic Pro'
            plotlyFont = 'Balto, sans-serif';
        case 'Hiragino Kaku Gothic ProN'
            plotlyFont = 'Balto, sans-serif';
        case 'Hiragino Kaku Gothic Std'
            plotlyFont = 'Balto, sans-serif';
        case 'Hiragino Kaku Gothic StdN'
            plotlyFont = 'Balto, sans-serif';
        case 'Hiragino Maru Gothic Pro'
            plotlyFont = 'Balto, sans-serif';
        case 'Hiragino Maru Gothic ProN'
            plotlyFont = 'Balto, sans-serif';
        case 'Hiragino Mincho Pro'
            plotlyFont = 'Times New Roman, Times, serif';
        case 'Hiragino Mincho ProN'
            plotlyFont = 'Times New Roman, Times, serif';
        case 'Hiragino Sans GB'
            plotlyFont = 'Balto, sans-serif';
        case 'Hobo Std'
            plotlyFont = 'Droid Sans, sans-serif';
        case 'Hoefler Text'
            plotlyFont = 'Times New Roman, Times, serif';
        case 'Impact'
            plotlyFont = 'Arial, sans-serif';
        case 'Imprint MT Shadow'
            plotlyFont = 'Arial, sans-serif';
        case 'InaiMathi'
            plotlyFont = 'Balto, sans-serif';
        case 'Kai'
            plotlyFont = 'Times New Roman, Times, serif';
        case 'Kailasa'
            plotlyFont = 'Arial, sans-serif';
        case 'Kannada MN'
            plotlyFont = 'PT Sans Narrow, sans-serif';
        case 'Kannada Sangam MN'
            plotlyFont =  'Open Sans, sans-serif';
        case 'Kefa'
            plotlyFont = 'Arial, sans-serif';
        case 'Khmer MN'
            plotlyFont = 'Balto, sans-serif';
        case 'Khmer Sangam MN'
            plotlyFont = 'Balto, sans-serif';
        case 'Kino MT'
            plotlyFont =  'Old Standard TT, serif';
        case 'Kokonor'
            plotlyFont =  'Gravitas One, cursive';
        case 'Kozuka Gothic Pr6N'
            plotlyFont = 'Arial, sans-serif';
        case 'Kozuka Gothic Pro'
            plotlyFont = 'Arial, sans-serif';
        case 'Kozuka Mincho Pr6N'
            plotlyFont = 'Times New Roman, Times, serif';
        case 'Kozuka Mincho Pro'
            plotlyFont = 'Times New Roman, Times, serif';
        case 'Krungthep'
            plotlyFont = 'Arial, sans-serif';
        case 'KufiStandardGK'
            plotlyFont = 'Arial, sans-serif';
        case 'Lao MN'
            plotlyFont = 'PT Sans Narrow, sans-serif';
        case 'Lao Sangam MN'
            plotlyFont = 'Balto, sans-serif';
        case 'Letter Gothic Std'
            plotlyFont = 'Courier New, monospace';
        case 'LiHei Pro'
            plotlyFont = 'Arial, sans-serif';
        case 'LiSong Pro'
            plotlyFont = 'Courier New, monospace';
        case 'Lithos Pro'
            plotlyFont = 'Gravitas One, cursive';
        case 'Lucida Blackletter'
            plotlyFont = 'Gravitas One, cursive';
        case 'Lucida Bright'
            plorltFont = 'Gravitas One, cursive';
        case 'Lucida Calligraphy'
            plorltFont = 'Gravitas One, cursive';
        case 'Lucida Console'
            plotlyFont = 'Balto, sans-serif';
        case 'Lucida Fax'
            plotlyFont = 'Old Standard TT, serif';
        case 'Lucida Grande'
            plotlyFont = 'Balto, sans-serif';
        case 'Lucida Handwriting'
            plotlyFont = 'Gravitas One, cursive';
        case 'Lucida Sans'
            plotlyFont = 'Arial, sans-serif';
        case 'Lucida Sans Typewriter'
            plotlyFont = 'Arial, sans-serif';
        case 'Lucida Sans Unicode'
            plotlyFont = 'Balto, sans-serif';
        case 'Malayalam MN'
            plotlyFont = 'PT Sans Narrow, sans-serif';
        case 'Malayalam Sangam MN'
            plotlyFont = 'Balto, sans-serif';
        case 'Marker Felt'
            plotlyFont = 'Gravitas One, cursive';
        case 'Marlett'
            plotlyFont = 'Arial, sans-serif';
        case 'Matura MT Script Capitals'
            plotlyFont = 'Gravitas One, cursive';
        case 'Meiryo'
            plotlyFont = 'Balto, sans-serif';
        case 'Menlo'
            plotlyFont = 'Balto, sans-serif';
        case 'Mesquite Std'
            plotlyFont = 'Gravitas One, cursive';
        case 'Microsoft Sans Serif'
            plotlyFont = 'Open Sans, sans-serif';
        case 'Minion Pro'
            plotlyFont = 'Times New Roman, Times, serif';
        case 'Mistral'
            plotlyFont = 'Gravitas One, cursive';
        case 'Modern No. 20'
            plotlyFont = 'Times New Roman, Times, serif';
        case 'Monaco'
            plotlyFont = 'Arial, sans-serif';
        case 'Monospaced'
            plotlyFont = 'Times New Roman, Times, serif';
        case 'Monotype Corsiva'
            plotlyFont = 'Gravitas One, cursive';
        case 'Monotype Sorts'
            plotlyFont = 'Balto, sans-serif';
        case 'MS Gothic'
            plotlyFont = 'Balto, sans-serif';
        case 'MS Mincho'
            plotlyFont = 'Courier New, monospace';
        case 'MS PGothic'
            plotlyFont = 'Arial, sans-serif';
        case 'MS PMincho'
            plotlyFont = 'Times New Roman, Times, serif';
        case 'MS Reference Sans Serif'
            plotlyFont = 'Arial, sans-serif';
        case 'MS Reference Specialty'
            plotlyFont = 'Balto, sans-serif';
        case 'Mshtakan'
            plotlyFont = 'Times New Roman, Times, serif';
        case 'MT Extra'
            plotlyFont = 'Arial, sans-serif';
        case 'Myanmar MN'
            plotlyFont = 'PT Sans Narrow, sans-serif';
        case 'Myanmar Sangam MN'
            plotlyFont = 'Balto, sans-serif';
        case 'Myriad Pro'
            plotlyFont = 'Arial, sans-serif';
        case 'Nadeem'
            plotlyFont = 'Arial, sans-serif';
        case 'Nanum Brush Script'
            plotlyFont = 'Gravitas One, cursive';
        case 'Nanum Gothic'
            plotlyFont = 'Arial, sans-serif';
        case 'Nanum Myeongjo'
            plotlyFont = 'Times New Roman, Times, serif';
        case 'Nanum Pen Script'
            plotlyFont = 'Gravitas One, cursive';
        case 'New Peninim MT'
            plotlyFont = 'Gravitas One, cursive';
        case 'News Gothic MT'
            plotlyFont = 'Arial, sans-serif';
        case 'Noteworthy'
            plotlyFont = 'Gravitas One, cursive';
        case 'Nueva Std'
            plotlyFont = 'Gravitas One, cursive';
        case 'OCR A Std'
            plotlyFont = 'Old Standard TT, serif';
        case 'Onyx'
            plotlyFont = 'PT Sans Narrow, sans-serif';
        case 'Optima'
            plotlyFont = 'Droid Serif, serif';
        case 'Orator Std'
            plotlyFont = 'PT Sans Narrow, sans-serif';
        case 'Oriya MN'
            plotlyFont = 'PT Sans Narrow, sans-serif';
        case 'Oriya Sangam MN'
            plotlyFont = 'Balto, sans-serif';
        case 'Osaka'
            plotlyFont = 'Arial, sans-serif';
        case 'Palatino'
            plotlyFont = 'Old Standard TT, serif';
        case 'Palatino Linotype'
            plotlyFont = 'Old Standard TT, serif';
        case 'Papyrus'
            plotlyFont = 'Gravitas One, cursive';
        case 'PCMyungjo'
            plotlyFont = 'Courier New, monospace';
        case 'Perpetua'
            plotlyFont = 'Droid Serif, serif';
        case 'Perpetua Titling MT'
            plotlyFont = 'Times New Roman, Times, serif';
        case 'PilGi'
            plotlyFont = 'Gravitas One, cursive';
        case 'Plantagenet Cherokee'
            plotlyFont = 'Times New Roman, Times, serif';
        case 'Playbill'
            plotlyFont = 'Arial, sans-serif';
        case 'PMingLiU'
            plotlyFont = 'Courier New, monospace';
        case 'Poplar Std'
            plotlyFont = 'Arial, sans-serif';
        case 'Prestige Elite Std'
            plotlyFont = 'Courier New, monospace';
        case 'PT Sans'
            plotlyFont = 'PT Sans Narrow, sans-serif';
        case 'PT Sans Caption'
            plotlyFont = 'Arial, sans-serif';
        case 'PT Sans Narrow'
            plotlyFont = 'PT Sans Narrow, sans-serif';
        case 'Raanana'
            plotlyFont = 'Times New Roman, Times, serif';
        case 'Rockwell'
            plotlyFont = 'Droid Serif, serif';
        case 'Rockwell Extra Bold'
            plotlyFont = 'Droid Serif, serif';
        case 'Rosewood Std'
            plotlyFont = 'Droid Serif, serif';
        case 'SansSerif'
            plotlyFont =  'Open Sans, sans-serif';
        case 'Sathu'
            plotlyFont = 'Arial, sans-serif';
        case 'Serif'
            plotlyFont = 'Times New Roman, Times, serif';
        case 'Silom'
            plotlyFont = 'Arial, sans-serif';
        case 'SimSun'
            plotlyFont = 'Courier New, monospace';
        case 'Sinhala MN'
            plotlyFont = 'Balto, sans-serif';
        case 'Sinhala Sangam MN'
            plotlyFont = 'Balto, sans-serif';
        case 'Skia'
            plotlyFont = 'Raleway, sans-serif';
        case 'Stencil'
            plotlyFont =  'Old Standard TT, serif';
        case 'Stencil Std'
            plotlyFont =  'Old Standard TT, serif';
        case 'STFangsong'
            plotlyFont = 'Times New Roman, Times, serif';
        case 'STHeiti'
            plotlyFont = 'Balto, sans-serif';
        case 'STIXGeneral'
            plotlyFont = 'Times New Roman, Times, serif';
        case 'STIXIntegralsD'
            plotlyFont = 'Arial, sans-serif';
        case 'STIXIntegralsSm'
            plotlyFont = 'Arial, sans-serif';
        case 'STIXIntegralsUp'
            plotlyFont = 'Arial, sans-serif';
        case 'STIXIntegralsUpD'
            plotlyFont = 'Arial, sans-serif';
        case 'STIXIntegralsUpSm'
            plotlyFont = 'Arial, sans-serif';
        case 'STIXNonUnicode'
            plotlyFont = 'Arial, sans-serif';
        case 'STIXSizeFiveSym'
            plotlyFont = 'Arial, sans-serif';
        case 'STIXSizeFourSym'
            plotlyFont = 'Arial, sans-serif';
        case 'STIXSizeOneSym'
            plotlyFont = 'Arial, sans-serif';
        case 'STIXSizeThreeSym'
            plotlyFont = 'Arial, sans-serif';
        case 'STIXSizeTwoSym'
            plotlyFont = 'Arial, sans-serif';
        case 'STIXVariants'
            plotlyFont = 'Arial, sans-serif';
        case 'STKaiti'
            plotlyFont = 'Times New Roman, Times, serif';
        case 'STSong'
            plotlyFont = 'Times New Roman, Times, serif';
        case 'Symbol'
            plotlyFont =  'Open Sans, sans-serif';
        case 'Tahoma'
            plotlyFont = 'Arial, sans-serif';
        case 'Tamil MN'
            plotlyFont = 'PT Sans Narrow, sans-serif';
        case 'Tamil Sangam MN'
            plotlyFont = 'Balto, sans-serif';
        case 'Tekton Pro'
            plotlyFont = 'Gravitas One, cursive';
        case 'Telugu MN'
            plotlyFont = 'Arial, sans-serif';
        case 'Telugu Sangam MN'
            plotlyFont = 'Arial, sans-serif';
        case 'Thonburi'
            plotlyFont = 'Arial, sans-serif';
        case 'Times'
            plotlyFont = 'Times New Roman, Times, serif';
        case 'Times New Roman'
            plotlyFont = 'Times New Roman, Times, serif';
        case 'Trajan Pro'
            plotlyFont = 'Times New Roman, Times, serif';
        case 'Trebuchet MS'
            plotlyFont = 'Arial, sans-serif';
        case 'Tw Cen MT'
            plotlyFont = 'Balto, sans-serif';
        case 'Verdana'
            plotlyFont = 'Arial, sans-serif';
        case 'Webdings'
            plotlyFont = 'Arial, sans-serif';
        case 'Wide Latin'
            plotlyFont = 'Gravitas One, cursive';
        case 'Zapf Dingbats'
            plotlyFont =  'Open Sans, sans-serif';
        case 'Zapfino'
            plotlyFont = 'Gravitas One, cursive';
        otherwise
            plotlyFont =  'Open Sans, sans-serif';
    end
catch
    display(['We had trouble identifying the font of your text. Please see',...
        'https://plot.ly/matlab for more information.']);
end
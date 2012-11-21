import os,sys , time
import StringIO
from  xlrd import open_workbook,cellname, colname , xldate_as_tuple
import datetime 
import codecs
args = sys.argv
if len(sys.argv) < 3:
	print 'Invalid input'
	print 'USAGE: xlstoxml.py <path to input xls file>  <output file path>'
	sys.exit()
input_file = sys.argv[1]
output_file = sys.argv[2]

if not os.path.isfile(input_file):
	print 'Input file does not exist'
	sys.exit()
book= open_workbook(input_file)
t1 = time.time()
out_str = StringIO.StringIO()
out_str.write(u'''<?xml version="1.0" encoding="UTF-8"?> <workbook>''' + u'\n')
for sheetidx in range(book.nsheets):
	sheet = book.sheet_by_index(sheetidx)
	out_str.write(u'<sheet>' + u'\n')
	out_str.write(u'<sheet_name type ="string"><![CDATA[' + sheet.name + u']]></sheet_name>' + u'\n')
	for row_index in range(sheet.nrows):
		out_str.write(u'<row index= "'+unicode((row_index + 1)) + u'">' + u'\n')
		for col_index in range(sheet.ncols):
			if sheet.cell(row_index,col_index).value!="":
				if	sheet.cell(row_index,col_index).ctype == 3: 
					DateValue =  xldate_as_tuple(sheet.cell(row_index,col_index).value ,book.datemode)
					CellValue = datetime.datetime(*DateValue).strftime('%Y-%m-%dT%H:%M:%S')
				try:
					if	sheet.cell(row_index,col_index).ctype <> 3: 
						CellValue  = unicode(sheet.cell(row_index,col_index).value)
				except 	UnicodeEncodeError, UnicodeDecodeError: 
					CellValue  = unicode(sheet.cell(row_index,col_index).value).encode("utf-8",'ignore')
				if sheet.cell(row_index,col_index).ctype == 1: 
					out_str.write(u'<cell column = "'+unicode(col_index+1)+u'" column_alpha="'+unicode(colname(col_index))+\
					u'" row="'+unicode(row_index+1)+u'" type ="string"><![CDATA[' + CellValue + u']]></cell>' + u'\n')
				elif sheet.cell(row_index,col_index).ctype == 2: 
					out_str.write(u'<cell column = "'+unicode(col_index+1)+u'" column_alpha="'+unicode(colname(col_index))+\
					u'" row="'+unicode(row_index+1)+u'" type ="numeric">' + CellValue + u'</cell>' + u'\n' )
				elif sheet.cell(row_index,col_index).ctype == 3: 
					out_str.write(u'<cell column = "'+unicode(col_index+1)+u'" column_alpha="'+unicode(colname(col_index))+\
					u'" row="'+unicode(row_index+1)+u'" type ="datetime"><![CDATA[' + CellValue + u']]></cell>' + u'\n' )
				else:
					out_str.write(u'<cell column = "'+unicode(col_index+1)+ u'" column_alpha="'+unicode(colname(col_index))+\
					u'" row="'+unicode(row_index+1)+u'" type ="string">' + CellValue + u'</cell>' + u'\n')
		out_str.write('</row>' + '\n')
	out_str.write('</sheet>' + '\n')
out_str.write('</workbook>')

file = codecs.open (output_file,'w',"utf-8")
file.write(out_str.getvalue())
file.close()
t2 = time.time()
print 'XLS to XML conversion took %0.3f s' % ((t2-t1))

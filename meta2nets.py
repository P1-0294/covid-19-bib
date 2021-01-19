# meta2nets - metadata.csv to Pajek bibliographic networks
# S2ORC to Pajek 0.1
# by Vladimir Batagelj, December 11, 2020

wdir = "C:/Users/batagelj/Documents/2020/corona/test"
ddir = "C:/Users/batagelj/Documents/2020/corona/test"
import sys, os, re, datetime, csv, json, shutil, time
os.chdir(wdir)
import nltk
from nltk.stem import WordNetLemmatizer
from nltk.corpus import wordnet
from nltk.corpus import stopwords

def get_wordnet_pos(word):
   """Map POS tag to first character lemmatize() accepts"""
   tag = nltk.pos_tag([word])[0][1][0].upper()
   tag_dict = {"J": wordnet.ADJ,
               "N": wordnet.NOUN,
               "V": wordnet.VERB,
               "R": wordnet.ADV}
   return tag_dict.get(tag, wordnet.NOUN)

def indAuthor(name):
# determines the index of an author
   global naut, aut, authors
   if name in aut:
     return aut[name]
   else:
     naut = naut + 1;
     aut[name] = naut
     authors.write(str(naut)+' "'+name+'"\n')
     return naut

def indJournal(name):
# determines the index of a journal
   global njr, jour, journals
   name = name.upper()
   if name in jour:
     return jour[name]
   else:
     njr = njr + 1;
     jour[name] = njr
     journals.write(str(njr)+' "'+name+'"\n')
     return njr

def indKeyword(name):
# determines the index of a keyword
   global nkw, keyw, keywords
   if name in keyw:
     return keyw[name]
   else:
     nkw = nkw + 1;
     keyw[name] = nkw
     keywords.write(str(nkw)+' "'+name+'"\n')
     return nkw

version = "S2ORC to Pajek 0.1"
print(version)
ts = datetime.datetime.now(); numrec = 0
print('{0}: {1}\n'.format("START",ts))

fromA = False; fromT = True; mstep = 5000; delfiles = False
works = open(wdir+'/works.tmp','w',encoding="utf-8-sig")
worksinfo = open(wdir+'/works.csv','w',encoding="utf-8-sig")
authors = open(wdir+'/authors.tmp','w',encoding="utf-8-sig")
years  = open(wdir+'/years.tmp','w')
journals  = open(wdir+'/journals.tmp','w',encoding="utf-8-sig")
authlinks  = open(wdir+'/authlinks.tmp','w')
keywlinks  = open(wdir+'/keywlinks.tmp','w')
jourlinks  = open(wdir+'/jourlinks.tmp','w')
keywords  = open(wdir+'/keywords.tmp','w',encoding="utf-8-sig")

aut  = {}; naut = 0
keyw = {}; nkw  = 0
jour = {}; njr  = 1
jour['*****'] = njr
journals.write(str(njr)+' "*****"\n')

lemmatizer = WordNetLemmatizer()
stop_words = set(stopwords.words("english"))
#add words that aren't in the NLTK stopwords list
add_words = ['!', '?', ',', ':', '&', '%', '.', '’', '(', ')', '[', ']']
new_stopwords = stop_words.union(add_words)

with open('metadata.csv',newline='',encoding="utf-8") as csvfile:
   csvreader = csv.DictReader(csvfile,delimiter=',',quotechar='"')
   numrec = 0
   worksinfo.write("num|name|pubTime|ID|DOI|PMC|pubMed\n")
   for row in csvreader:
      numrec += 1
      # if numrec > 2000: break
      if (numrec % mstep) == 0:
         print('{0}: {1}'.format(numrec,datetime.datetime.now()))        
      years.write('{0}: {1} {2} {3}\n'.format(numrec,row["cord_uid"],
         row["publish_time"],row["source_x"]))
      Au = row["authors"].split(";")
      firstAu = Au[0].strip() if len(Au)>0 else "Anonymous" 
      name = firstAu.split(",")[0] if len(firstAu)>0 else "Anonymous" 
      worksinfo.write(str(numrec)+"|"+name+"|"+row["publish_time"]+"|"+\
         row['cord_uid']+"|"+row['doi']+"|"+row['pmcid']+"|"+row['pubmed_id']+"\n")
      works.write(str(numrec)+' "'+name+':'+row["publish_time"]+'"\n')
      #   row['cord_uid'])
      for s in Au:
         iauth = indAuthor(s.strip())
         authlinks.write("{0} {1}\n".format(numrec,iauth))
      S = (row["title"]+" "+row["abstract"] if fromA & fromT else\
          row["abstract"] if fromA else row["title"])\
          .lower().replace("/"," ").replace("-"," ")
      L = set([lemmatizer.lemmatize(w, get_wordnet_pos(w)) for\
               w in nltk.word_tokenize(S)])
      C = set([w for w in L if w not in new_stopwords])
      for k in C:
         ikeyw = indKeyword(k)
         keywlinks.write("{0} {1}\n".format(numrec,ikeyw))
      ijour = indJournal(row["journal"])
      jourlinks.write("{0} {1}\n".format(numrec,ijour))
      
authors.close(); journals.close(); keywords.close()
worksinfo.close(); works.close(); years.close()
authlinks.close(); keywlinks.close(); jourlinks.close()

print("number of works    ={0:7}".format(numrec))
print("number of authors  ={0:7}".format(naut))
print("number of journals ={0:7}".format(njr))
print("number of keywords ={0:7}".format(nkw))

tr = datetime.datetime.now()
print('{0}: {1}\n'.format(numrec,tr))

# time.sleep(3)

# works X authors network
print("works X authors  network: "+wdir+"/WA.net\n")
works  = open(wdir+'/works.tmp','r',encoding="utf-8-sig")
authors = open(wdir+'/authors.tmp','r',encoding="utf-8-sig")
wa  = open(wdir+'/WA.net','w',encoding="utf-8-sig")
wa.write("% created by "+version+" "+datetime.datetime.now().ctime()+"\n")
wa.write('*vertices '+str(numrec+naut)+' '+str(numrec)+'\n')
shutil.copyfileobj(works,wa)
works.close()
while True:
   line = authors.readline()
   if not line: break
   s = line.split(" ",1)
   wa.write(str(eval(s[0])+numrec)+' '+s[1])
temp  = open(wdir+'/authlinks.tmp','r')
wa.write('*arcs\n')
while True:
   line = temp.readline()
   if not line: break
   s = line.split(" ")
   wa.write(s[0]+' '+str(eval(s[1])+numrec)+'\n')
temp.close(); wa.close(); authors.close()

# works X journals network
print("works X journals  network: "+wdir+"/WJ.net\n")
works  = open(wdir+'/works.tmp','r',encoding="utf-8-sig")
journals = open(wdir+'/journals.tmp','r',encoding="utf-8-sig")
wj  = open(wdir+'/WJ.net','w',encoding="utf-8-sig")
wj.write("% created by "+version+" "+datetime.datetime.now().ctime()+"\n")
wj.write('*vertices '+str(numrec+njr)+' '+str(numrec)+'\n')
shutil.copyfileobj(works,wj)
works.close()
while True:
   line = journals.readline()
   if not line: break
   s = line.split(" ",1)
   wj.write(str(eval(s[0])+numrec)+' '+s[1])
temp  = open(wdir+'/jourlinks.tmp','r')
wj.write('*arcs\n')
while True:
   line = temp.readline()
   if not line: break
   s = line.split(" ")
   wj.write(s[0]+' '+str(eval(s[1])+numrec)+'\n')
temp.close(); wj.close(); journals.close()

# works X keywords network
print("works X keywords  network: "+wdir+"/WK.net\n")
works  = open(wdir+'/works.tmp','r',encoding="utf-8-sig")
keywords = open(wdir+'/keywords.tmp','r',encoding="utf-8-sig")
wk  = open(wdir+'/WK.net','w',encoding="utf-8-sig")
wk.write("% created by "+version+" "+datetime.datetime.now().ctime()+"\n")
wk.write('*vertices '+str(numrec+nkw)+' '+str(numrec)+'\n')
shutil.copyfileobj(works,wk)
works.close()
while True:
   line = keywords.readline()
   if not line: break
   s = line.split(" ",1)
   wk.write(str(eval(s[0])+numrec)+' '+s[1])
temp  = open(wdir+'/keywlinks.tmp','r')
wk.write('*arcs\n')
while True:
   line = temp.readline()
   if not line: break
   s = line.split(" ")
   wk.write(s[0]+' '+str(eval(s[1])+numrec)+'\n')
temp.close(); wk.close(); keywords.close()

if delfiles:
   try:
      os.remove(wdir+'/works.tmp')
      os.remove(wdir+'/authors.tmp');  os.remove(wdir+'/authlinks.tmp')      
      os.remove(wdir+'/keywords.tmp'); os.remove(wdir+'/keywlinks.tmp')
      os.remove(wdir+'/journals.tmp'); os.remove(wdir+'/jourlinks.tmp')
      # os.remove(wdir+'/years.tmp'); os.remove(wdir+'/works.csv')
   except:
      print("unable to delete some temp files")

tf = datetime.datetime.now()
print('{0}: {1}\n'.format("END",tf))

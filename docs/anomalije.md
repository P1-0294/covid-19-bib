# Anomalije

## CORD-19

[CORD-19](https://arxiv.org/abs/2004.10706) (COVID-19 Open Research Dataset) is obtained from various sources. The sources include:

- PMC
- Medline
- BioRxiv
- ArXiv
- Elsevier
- MedRxiv
- WHO

It was updated daily until Feb 2021, now is being updated weekly or even more rarely.

First release: 16 Mar, 2020.

### Processing

- collection and ingestion done through [Semantic Scholar literature search engine](https://semanticscholar.org/)
- metadata is harmonized and deduplicated
- paper documents parsed through [S2ORC pipeline](https://arxiv.org/abs/1911.02782)

### Data description

Data consists of the file `metadata.csv`, two folders with JSON files from parsed PDFs and parsed PMC(XML) files and some additional data.

#### `Metadata.csv`

[Detailed column description](https://github.com/allenai/cord19#metadatacsv-overview)

- identifiers:
  - `cord_uid`- unique identifier for the paper
  - `sha`- SHA of all attached PDFs, `;`-separated  
  - `doi`- DOI
  - `pmcid`- PubMed ID
  - `pubmed_id`- PubMed Central ID, if exists  
  - `arxiv_id`- ArXiv 
  - `mag_id`- [MAG identifier](https://www.aclweb.org/anthology/P18-4015/)   
  - `who_covidence_id`- [WHO Covidence #](https://www.who.int/emergencies/diseases/novelcoronavirus-
2019/global-research-on-novel-coronavirus-
2019-ncov), if exists
  - `s2_id`- Semantic Scholar ID
  
- article data  
  - `source_x`- Source description. Comma separ 
  - `title`- article title  
  - `license`- type of license  
  - `abstract`- article abstract 
  - `publish_time`- publish date in form `yyyy-mm-dd` 
  - `authors`- `;`-separated list of authors
  - `journal`- journal identifier  

- links to additional data:
  - `pdf_json_files`- `;`-separated internal links to JSON files of parsed PDFs  
  - `pmc_json_files`- `;`-separated internal links to JSON files obtained from parsed XML PMC files
  - `url`- `;`-separated list of external 

### Overview of the dataset

Version `2021-03-08`

<!--- metadata0 %>% pull(cord_uid) %>% unique() %>% length() -->
- unique `cord_uid`s: 457294 
<!--- metadata %>% select(source_x) %>% distinct() %>% separate_rows(source_x, sep=";") %>%  pull(source_x) %>% str_trim() %>% unique() %>% length() -->
- number of sources: 7
<!--- metadata0 %>% pull(doi) %>% .[!is.na(.) & . != ""] %>% unique() %>% length() -->
- unique DOI entries: 266295
<!--- metadata0 %>% pull(pmcid) %>% .[!is.na(.) & . != ""] %>% unique() %>% length() -->
- unique `pmcid`: 170722
<!--- metadata0 %>% pull(pubmed_id) %>% .[!is.na(.) & . != ""] %>% unique() %>% length() -->
- unique `pubmed_id`: 233243
<!--- metadata0 %>% pull(arxiv_id) %>% .[!is.na(.) & . != ""] %>% unique() %>% length() -->
- unique `arxiv_id`: 6377
<!--- metadata0 %>% pull(mag_id) %>% .[!is.na(.) & . != ""] %>% unique() %>% length() -->
- unique `mag_id`: 0
<!--- metadata0 %>% pull(who_covidence_id) %>% .[!is.na(.) & . != ""] %>% unique() %>% length() -->
- unique `who_covidence_id`: 197114
<!--- metadata0 %>% pull(s2_id) %>% .[!is.na(.) & . != ""] %>% unique() %>% length() -->
- unique `s2_id`: 197114

### Authors

One of the challenges in bibliographic data is entity resolution, in particular related to authors.
The first step is cleaning the authors data from CORD-19. In what follows we describe challenges encountered and methods for addressing them.

#### Different author strings

Article metadata is obtained from different sources. Different sources use different conventions for stating author names. For each `cord_uid` there can be several row entries representing an article for different sources.
Groups of rows (article entries) with the same `cord_uid` can hence have different `;`-separated strings of authors. 

<!--- metadata0 %>% filter(cord_uid %in% test.moreThan3Author) %>% arrange(cord_uid) %>% select(cord_uid, authors, title, abstract, source_x) %>% View
-->
In particular, if we take `cord_uid` groups with more than 2 different strings there are `235` such groups.  

#### Different author notation regarding name

```
03kd1kby
Keane, M. J.
Keane, Michael J
```
#### No abstract, same title 

```
0fpcz26q, 1i2zpp1y
```

#### Bad parsing, especially for long
```
0vuuqulo
Lima, Rodrigo Moreira e Reis Leonardo de Andrade Lara Felipe Souza Thyrso de Dias Lino Correa Matsumoto Márcio Mizubuti Glenio Bitencourt Hamaji Adilson Cabral Lucas Wynne Mathias Lígia Andrade da Silva Telles Lima Lais Helena Navarro e

Lima, Rodrigo Moreira e; Reis, Leonardo de Andrade; Lara, Felipe Thyrso de Souza; Dias, Lino Correa; M

Moreira e Lima, Rodrigo; Reis, Leonardo de Andrade; de Lara, Felipe Souza Thyrso; Dias, Lino Correa; M
```

#### Unicode characters

```
0vuuqulo
Pérez-Sastré, Miguel A; Valdés, Jesús; Ortiz-Hernández, Luis
Pérez-Sastré, M. A.; Valdés, J.; Ortiz-Hernández, L.
Perez-Sastr, M. A.; Valdes, J.; Ortiz-Hernandez, L.
```

#### Dot-no-dot
```
1c8juvru
Kilinc, D; van de Pasch, S; Doets, A Y; Jacobs, B C; van Vliet, J; Garssen, M P J
Kilinc, D.; van de Pasch, S.; Doets, A. Y.; Jacobs, B. C.; van Vliet, J.; Garssen, M. P. J.
```

#### Different authors entries

```
2adn82gf
Hayashi, Seiji
Chavez, Annette
Hayashi, Seiji; Chavez, Annette
```

#### Mix of all

```
2rqk52f5
Latini, A.; Magri, F.; Dona, M. G.; Giuliani, M.; Cristaudo, A.; Zaccarelli, M.

Alessandra, Latini; Francesca, Magri; Maria Gabriella, Donà; Massimo, Giuliani; Antonio, Cristaudo; Mauro, Zaccarelli

Latini, Alessandra; Magri, Francesca; Donà, Maria Gabriella; Giuliani, Massimo; Cristaudo, Antonio; Zaccarelli, Mauro
```

#### Anonymous or no authors

```
31qsxdbs
```


#### Wrong author separation in long author lists

#### Apostrophe parsing (039)

```
02n3sxvd
O039,; Sullivan, Owen P
```

```
009jy6hs
Williams, Joshua T B; O039,; Leary, Sean T; Nussbaum, Abraham M
```

```
04kjkrp0
Al-Shar039,; i, Nizar A
```

```
07bjwas5
Wiseman, Jessica; D039,; Amico, Timothy A.; Zawadzka, Sabina; Anyimadu, Henry
```

```
0fqf8vha
Jum039,; ah, Ahmad A; Elsalem, Lina; Loch, Carolina; Sch
```

```
0ndzswbp
Kaholokula, Joseph Keawe039; aimoku,; Samoa, Raynald
```

```
0s6x8q2s
Rabbani, M. R.; Abdulla, Y.; Basahr, A.; Khan, S.; Moh039,; d Ali, M. A.
```

March 2021: 2827 papers

#### Wrong parsing of HTML codes of form &xxx;

Mostly for Turkish authors. Usually causes wrong parsing.

```
3lvscu5x
Vatan, Asli Güçlü Ertu amp rul Ö amp ütlü Aziz 
Vatan, Asli; Güçlü, Ertuamp; 287,; rul,; Öamp,; ü
Vatan, Asli; Güçlü, Ertugrul; Ögütlü, Aziz; Kibar, Fulya Aktan; Karabay, Oguz
```

```
q5l62qdn
Acar, Türkan; Acar, Bilgehan Atamp; 305,; lgan,; Aras, Yeamp; 351,; Güzey, im; Doamp,; 287,; an, Tura

Acar, Türkan; Acar, Bilgehan Atilgan; Aras, Yesim Güzey; Dogan, Turan; Boncuk, Sena; Eryilmaz, Halil Alper; Can, Nimet; Can, Yusuf
```

```
15j5401j
Çamp,; 305,; nar, Tufan; Hayamp,; roamp,; 287,; lu, Me
Çinar, Tufan; Hayiroglu, Mert Ilker; Çiçek, Vedat; Uzun, 
```

```
b5w9983z
Işık, Sıla amp; Iacute,; biş, Hazal Gulseven Osman
```

```
dwtcno3b
Elmacıoğlu, F.; Emiroğlu, E.; amp,; Uuml,; lker, M. T.; Özy
```

```
eui5xhet
Şimşek, Feride amp; Iacute,; rem,
```

```
fhi315de
Erdoğan Orhan, amp; Iacute,; Yıldız, M.
```

#### Prefixes in arab names and capitalization

```
404tng58
el-Guebaly, Nady
El-Guebaly, N.
```

#### Generic papers/titles with no abstract and mixing paper cluster    

Editor's Note, Response to Letter to the Editor, Editorial Comment, Corrigendum, Author's response,
Letters to the editor, Brazil's COVID-19 response, From the Editors, COVID-19 Testing, Journal club,
Correction, In Response, Covid-19, The Authors Reply, Authors' Reply, Reply, Commentary, The authors reply, Guest editorial, Letter to the Editor, Authors' response, Reader response: Neurologic complications of coronavirus infections, Response, Letter from the UK, In Reply, 
In reply, The Reply, Guest Editorial, Highlights from this issue, From the Editor, Editorial Note, Reply by Authors

#### Generational suffixes

```
Jr, Sr, 2nd, 3rd, III, 
```

```
2nyfadkr
Escher, A. R.; Jr.,
```

```
eua7gycl
Qian, L. W.; Fourcaudot, A. B.; Chen, P.; Brandenburg, K. S.; Weaver, A. J.; Jr.,; Leung, K. P.
```

```
drerckps
Baker, Christopher; Sr.,; Baker Sr, Christopher
```

```
ich2t5wl
Hennessy, Mike; Sr.,
```

```
ez1n0js8
Deb, C.; Moneer, O.; Price, W. N.; 2nd,
```

```
yxdf15ji
Beaupre, R.; 2nd, Petrie; C.,; Toledo, A.
```

```
dihq3dff
Hasan, S.; Press, R. H.; Chhabra, A.; Choi, J. I.; Simone, C. B.
Hasan, S.; Press, R. H.; Chhabra, A.; Choi, J. I.; Simone, C. B.; 2nd,
```

```
1cxaj692
Goodloe, T. B.; 3rd, Walter L. A.
```

```
cyrwp459
Meltzer, C. C.; Wiggins, R. H.; 3rd, Mossa-Basha M.; Pala
Meltzer, Carolyn C; Wiggins, Richard H; Mossa-Basha, M
```

```
2i8hpabu
Sang, C. J.; 3rd, Heindl B.; Von Mering, G.; Rajapreyar, I.
```

```
539530gh
Knight, Stacey; III, Russell R. Miller; Bair, Tami; Horne, Benjamin; Lopansri, Bert K.; Anderson, Jeffrey; Muhlestein, J.; Carlquist, John
```

```
osiegawa
Dukes, Albert D.; III,
```

#### Different notations for "et. al"

```
5hpniqon
Gupta, Shruti; Hayek, Salim S; Wang, Wei; al.,; et,
```

```
6yhgtgzz
De Rossi, N; Scarpazza, C; Filippini, C; Cordioli, C; al.,; et,
```

```
9sj6rw8i
Haberman, Rebecca; Axelrad, Jordan; Chen, Alan; al, et
```

```
e8aw8ebt
Chandir, Subhash; Siddiqi, Danya Arif; Setayesh, Hamidreza; al, et
```

#### Single letter authors

```
b6or1n6b
Л.,; Насонов, Е.
```

```
3g9v3y7q
Lekha, Hannah; R.,
```

```
giz2w8xm
Abidin, Suryanto; T.,; Utami, P.
```

```
502acsee
Lyadov, K. V.; Koneva, E. S.; Polushkin, V. G.; E.,; Yu.,
```

#### Wrong parsing (comma at the end)

#### Unicode normalization

https://stackoverflow.com/questions/53141997/what-is-this-crazy-german-character-combination-to-represent-an-umlaut
https://stackoverflow.com/questions/33561962/umlaut-matching-in-r-regex
https://withblue.ink/2019/03/11/why-you-need-to-normalize-unicode-strings.html

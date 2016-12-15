SPARQL

PREFIX uniprot: <http://purl.uniprot.org/core/>

SELECT distinct (substr(str(?embl),34) as ?emblid) ?full ?taxuri
FROM <http://togoannotator.jp/cellular>
WHERE {
?uniprotid a uniprot:Protein ;
  uniprot:organism ?taxon ;
  rdfs:seeAlso ?embl ;
  uniprot:recommendedName [
    a uniprot:Structured_Name ;
    uniprot:fullName ?full ]
  .
?embl a uniprot:Nucleotide_Resource .
FILTER (!strstarts(str(?embl), "file:"))
BIND(iri(concat("http://identifiers.org", substr(str(?taxon), 24))) as ?taxuri)
}
;

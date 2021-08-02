from typing import Dict, List, Optional

from pydantic import BaseModel


# APIリクエストのスキーマ
class Query(BaseModel):
    query: str
    type: Optional[str]
    limit: Optional[int]
    properties: Optional[list]
    type_strict: Optional[str]


class ReconciliationRequest(BaseModel):
    __root__: Optional[Dict[str, Query]]


# マニフェストのスキーマ
class Suggest(BaseModel):
    entity: str
    property: dict
    type: str


class EndpointType(BaseModel):
    id: str
    name: str


class ManifestResponse(BaseModel):
    versions: List[str]
    name: str
    identifierSpace: str
    schemaSpace: str
    defaultTypes: List[EndpointType]
    view: str
    feature_view: str
    preview: dict
    suggest: Suggest
    extend: str


class Feature(BaseModel):
    id: str
    value: str


class ReconciliationResult(BaseModel):
    id: str
    name: str
    description: Optional[str]
    type: Optional[List[dict]]
    score: float
    features: Optional[List[Feature]]
    match: bool


class ReconciliationResponse(BaseModel):
    __root__: Dict[str, Dict[str, List[ReconciliationResult]]]
